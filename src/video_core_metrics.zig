pub const Metrics = struct {
    board_model: u32,
    board_revision: u32,
    firmware_revision: u32,
    is_qemu: bool,
    max_temperature: u32,
    temperature: u32,
    temperature_id: u32,
    arm_memory_address: u32,
    arm_memory_size: u32,
    vc_memory_address: u32,
    vc_memory_size: u32,
    usable_dma_channels_mask: u32,

    pub fn init(self: *Metrics) void {
        self.temperature_id = 0;
        callVideoCoreProperties(&[_]PropertiesArg{
            tag(TAG_GET_FIRMWARE_REVISION, 4),
            out(&self.firmware_revision),
            tag(TAG_GET_BOARD_MODEL, 4),
            out(&self.board_model),
            tag(TAG_GET_BOARD_REVISION, 4),
            out(&self.board_revision),
            tag(TAG_GET_MAX_TEMPERATURE, 8),
            set(&self.temperature_id),
            out(&self.max_temperature),
            tag(TAG_GET_ARM_MEMORY, 8),
            out(&self.arm_memory_address),
            out(&self.arm_memory_size),
            tag(TAG_GET_VC_MEMORY, 8),
            out(&self.vc_memory_address),
            out(&self.vc_memory_size),
            tag(TAG_GET_USABLE_DMA_CHANNELS_MASK, 4),
            out(&self.usable_dma_channels_mask),
            lastTagSentinel(),
        });
        self.is_qemu = self.board_model == 0xaaaaaaaa;
        self.update();
    }

    pub fn update(m: *Metrics) void {
        callVideoCoreProperties(&[_]PropertiesArg{
            tag(TAG_GET_TEMPERATURE, 8),
            set(&m.temperature_id),
            out(&m.temperature),
            lastTagSentinel(),
        });
    }
};

const TAG_GET_ARM_MEMORY = 0x10005;
const TAG_GET_BOARD_MODEL = 0x10001;
const TAG_GET_BOARD_REVISION = 0x10002;
const TAG_GET_FIRMWARE_REVISION = 0x00001;
const TAG_GET_MAX_TEMPERATURE = 0x3000A;
const TAG_GET_TEMPERATURE = 0x30006;
const TAG_GET_USABLE_DMA_CHANNELS_MASK = 0x60001;
const TAG_GET_VC_MEMORY = 0x10006;

const panic = @import("debug.zig").panic;
use @import("video_core_properties.zig");
