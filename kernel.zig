const MultibootHeader = packed struct {
    magic: usize,
    flags: usize,
    checksum: usize,
};

const MAGIC   = usize(0x1badb002); // so bootloader can find header
const ALIGN   = usize(0b0);     // align loaded modules on page boundaries
const MEMINFO = usize(0b1);     // provide memory map
const FLAGS   = ALIGN | MEMINFO;

export const multiboot_header = MultibootHeader {
    .magic = MAGIC,
    .flags = FLAGS,
    .checksum = ~(MAGIC +% FLAGS) +% 1,
};

var stack: [16 * 1024]u8 = undefined;
var stack_top: usize = undefined;

export nakedcc fn _start() -> unreachable {
    @setGlobalSection(multiboot_header, ".multiboot");
    @setGlobalAlign(multiboot_header, 4);

    stack_top = usize(&stack) + stack.len;

    // set up the stack by pointing the esp register at the top
    // stack grows downwards on x86 systems
    asm volatile (""
        :
        : [stack_top] "{esp}" (stack_top)
        );

    @setGlobalAlign(stack, 16);
    kernel_main();

    // hang
    while (true) {}
}

// Hardware text mode color constants
const VgaColor = u8; // TODO make a typedef
const VGA_COLOR_BLACK = 0;
const VGA_COLOR_BLUE = 1;
const VGA_COLOR_GREEN = 2;
const VGA_COLOR_CYAN = 3;
const VGA_COLOR_RED = 4;
const VGA_COLOR_MAGENTA = 5;
const VGA_COLOR_BROWN = 6;
const VGA_COLOR_LIGHT_GREY = 7;
const VGA_COLOR_DARK_GREY = 8;
const VGA_COLOR_LIGHT_BLUE = 9;
const VGA_COLOR_LIGHT_GREEN = 10;
const VGA_COLOR_LIGHT_CYAN = 11;
const VGA_COLOR_LIGHT_RED = 12;
const VGA_COLOR_LIGHT_MAGENTA = 13;
const VGA_COLOR_LIGHT_BROWN = 14;
const VGA_COLOR_WHITE = 15;
 
fn vga_entry_color(fg: VgaColor, bg: VgaColor) -> u8 {
    return fg | (bg << 4);
}
 
fn vga_entry(uc: u8, color: u8) -> u16 {
    return u16(uc) | (u16(color) << 8);
}
 
const VGA_WIDTH = 80;
const VGA_HEIGHT = 25;

const terminal = struct {
    var row = usize(0);
    var column = usize(0);
    var color = vga_entry_color(VGA_COLOR_LIGHT_GREY, VGA_COLOR_BLACK);

    const buffer = (&u16)(0xB8000);

    fn initialize() {
        {var y = usize(0); while (y < VGA_HEIGHT; y += 1) {
            {var x = usize(0); while (x < VGA_WIDTH; x += 1) {
                putCharAt(' ', color, x, y);
            }}
        }}
    }
    
    fn setColor(new_color: u8) {
        color = new_color;
    }
    
    fn putCharAt(c: u8, new_color: u8, x: usize, y: usize) {
        const index = y * VGA_WIDTH + x;
        @volatileStore(&buffer[index], vga_entry(c, new_color));
    }
    
    fn putChar(c: u8) {
        putCharAt(c, color, column, row);
        column += 1;
        if (column == VGA_WIDTH) {
            column = 0;
            row += 1;
            if (row == VGA_HEIGHT)
                row = 0;
        }
    }
    
    fn write(data: []const u8) {
        for (data) |c| putChar(c);
    }
 
};
 
fn kernel_main() {
    terminal.initialize();
    terminal.write("Hello, kernel World!\n");
}
