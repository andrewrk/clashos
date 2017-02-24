use @import("int_types.zig");

const panic = @import("main.zig").panic;
const assert = @import("std").debug.assert;
const log = @import("serial.zig").log;
const dumpMemory = @import("serial.zig").dumpMemory;

const maximum_devices = 8;
var devices = []?UsbDevice{null} ** maximum_devices;

const interface_class_attach_count = 16;
const interfaceFn = fn(device: &UsbDevice, interface_number: u32) -> %void;
var interface_class_attach = []?interfaceFn{null} ** interface_class_attach_count;

error General;
error Argument;
error Retry;
error Device;
error Incompatible;
error Compiler;
error Memory;
error Timeout;
error Disconnected;

const UsbDirection = enum {
    HostToDevice,
    DeviceToHost,
};
const Out = UsbDirection.HostToDevice;
const In = UsbDirection.DeviceToHost;

const UsbSpeed = enum {
    High,
    Full,
    Low,
};

const UsbTransfer = enum {
    Control,
    Isochronous,
    Bulk,
    Interrupt,
};

const UsbDeviceStatus = enum {
    Attached,
    Powered,
    Default,
    Addressed,
    Configured,
};

const InterfaceClass = struct {
    const Reserved = 0x0;
    const Audio = 0x1;
    const Communications = 0x2;
    const Hid = 0x3;
    const Physical = 0x5;
    const Image = 0x6;
    const Printer = 0x7;
    const MassStorage = 0x8;
    const Hub = 0x9;
    const CdcData = 0xa;
    const SmartCard = 0xb;
    const ContentSecurity = 0xd;
    const Video = 0xe;
    const PersonalHealthcare = 0xf;
    const AudioVideo = 0x10;
    const DiagnosticDevice = 0xdc;
    const WirelessController = 0xe0;
    const Miscellaneous = 0xef;
    const ApplicationSpecific = 0xfe;
    const VendorSpecific = 0xff;
};

const TransferError = struct {
    const None = 0;
    const Stall = 1 << 1;
    const BufferError = 1 << 2;
    const Babble = 1 << 3;
    const NoAcknowledge = 1 << 4;
    const CrcError = 1 << 5;
    const BitError = 1 << 6;
    const ConnectionError = 1 << 7;
    const AhbError = 1 << 8;
    const NotYetError = 1 << 9;
    const Processing = 1 << 31;
};

const DescriptorType = struct {
    const Device = 1;
    const Configuration = 2;
    const String = 3;
    const Interface = 4;
    const Endpoint = 5;
    const DeviceQualifier = 6;
    const OtherSpeedConfiguration = 7;
    const InterfacePower = 8;
    const Hid = 33;
    const HidReport = 34;
    const HidPhysical = 35;    
    const Hub = 41;
};

const max_children_per_device = 10;
const max_interfaces_per_device = 8;
const max_endpoints_per_device = 16;

const UsbInterfaceDescriptor = packed struct {
    descriptor_length: u8,
    descriptor_type: u8,
    number: u8,
    alternate_setting: u8,
    endpoint_count: u8,
    class: u8,
    sub_class: u8,
    protocol: u8,
    string_index: u8,
};

const Synchronization = enum {
    None,
    Asynchronous,
    Adaptive,
    Synchrouns,
};

const Usage = enum {
    Data,
    Feeback,
    ImplicitFeebackData,
};

const Transactions = enum {
    None,
    Extra1,
    Extra2,
};

const UsbEndpointDescriptor = packed struct {
    descriptor_length: u8,
    descriptor_type: u8,
    endpoint_address: packed struct {
        number: u4,
        _reserved4_6: u3,
        direction: u1, // UsbDirection
    },
    attributes: packed struct {
        transfer_type: u2,
        synchronization: u2, // Synchronization
        usage: u2, // Usage
        _reserved6_7: u2,
    },
    packet: packed struct {
        max_size: u11,
        transactions: u2,
        _reserved13_15: u3,
    },
    interval: u8,
};

const UsbDevice = struct {
    number: u32,

    speed: UsbSpeed,
    status: UsbDeviceStatus,
    configuration_index: u8,
    port_number: u8,
    err: u32,

    interfaces: [max_interfaces_per_device]UsbInterfaceDescriptor,
    endpoints: [max_interfaces_per_device]UsbEndpointDescriptor,
};

const AxiBurstLength = enum {
    Length4,
    Length3,
    Length2,
    Length1,
};

const EmptyLevel = enum {
    Half,
    Empty,
};

const DmaRemainderMode = enum {
    Incremental,
    Single,
};

const UMode = enum {
    ULPI,
    UTMI,
};

const CoreFifoFlush = enum {
    FlushNonPeriodic,
    FlushPeriodic1,
    FlushPeriodic2,
    FlushPeriodic3,
    FlushPeriodic4,
    FlushPeriodic5,
    FlushPeriodic6,
    FlushPeriodic7,
    FlushPeriodic8,
    FlushPeriodic9,
    FlushPeriodic10,
    FlushPeriodic11,
    FlushPeriodic12,
    FlushPeriodic13,
    FlushPeriodic14,
    FlushPeriodic15,
    FlushAll,
};

pub fn init() -> %void {
    interface_class_attach[InterfaceClass.Hid] = hidAttach;

    comptime assert(@sizeOf(UsbDeviceRequest) == 0x8);

    %return hcdInitialize();
    %defer hcdDeinitialize();

    %return hcdStart();
    %defer hcdStop();

    %return usbAttachRootHub();
}

fn hcdStart() -> %void {
    panic("TODO hcdStart");
}

fn hcdStop() {
    panic("TODO hcdStop");
}

fn usbAttachRootHub() -> %void {
    panic("TODO usbAttachRootHub");
}

/// The interrupts in the core register.
///
/// Contains the core interrutps that controls the DesignWare® Hi-Speed USB 2.0
/// On-The-Go (HS OTG) Controller.
const CoreInterrupts = packed struct {
    CurrentMode: bool,
    ModeMismatch: bool,
    Otg: bool,
    DmaStartOfFrame: bool,
    ReceiveStatusLevel: bool,
    NpTransmitFifoEmpty: bool,
    ginnakeff: bool,
    goutnakeff: bool,
    ulpick: bool,
    I2c: bool,
    EarlySuspend: bool,
    UsbSuspend: bool,
    UsbReset: bool,
    EnumerationDone: bool,
    IsochronousOutDrop: bool,
    eopframe: bool,
    RestoreDone: bool,
    EndPointMismatch: bool,
    InEndPoint: bool,
    OutEndPoint: bool,
    IncompleteIsochronousIn: bool,
    IncompleteIsochronousOut: bool,
    fetsetup: bool,
    ResetDetect: bool,
    Port: bool,
    HostChannel: bool,
    HpTransmitFifoEmpty: bool,
    LowPowerModeTransmitReceived: bool,
    ConnectionIdStatusChange: bool,
    Disconnect: bool,
    SessionRequest: bool,
    Wakeup: bool,
};

const PacketStatus = struct {
    const InPacket = 2;
    const InTransferComplete = 3;
    const DataToggleError = 5;
    const ChannelHalted = 7;
};

const ReceiveStatus = packed struct {
    ChannelNumber: u4,
    bcnt: u11,
    dpid: u2,
    PacketStatus: u4, // PacketStatus
    _reserved21_31: u11,
};

const FifoSize = packed struct {
    StartAddress: u16,
    Depth: u16,
};

const CoreGlobalRegsTokenType = enum {
    InOut,
    ZeroLengthOut,
    PingCompleteSplit,
    ChannelHalt,
};

const HostGlobalRegsTokenType = enum {
    ZeroLength,
    Ping,
    Disable,
};

const OperatingMode = enum {
    HNP_SRP_CAPABLE,
    SRP_ONLY_CAPABLE,
    NO_HNP_SRP_CAPABLE,
    SRP_CAPABLE_DEVICE,
    NO_SRP_CAPABLE_DEVICE,
    SRP_CAPABLE_HOST,
    NO_SRP_CAPABLE_HOST,
};

const Architecture = enum {
    SlaveOnly,
    ExternalDma,
    InternalDma,
};

const HighSpeedPhysical = enum {
    NotSupported,
    Utmi,
    Ulpi,
    UtmiUlpi,
};

const FullSpeedPhysical = enum {
    Physical0,
    Dedicated,
    Physical2,
    Physcial3,
};

const UtmiPhysicalDataWidth = enum {
    Width8bit,
    Width16bit,
    Width8or16bit,
};

/// Contains the core global registers structure that control the HCD.
/// 
/// Contains the core global registers structure that controls the DesignWare®
/// Hi-Speed USB 2.0 On-The-Go (HS OTG) Controller.
const CoreGlobalRegs = packed struct {
    OtgControl: packed struct {
        sesreqscs: bool,
        sesreq: bool,
        vbvalidoven: bool,
        vbvalidovval: bool,
        avalidoven: bool,
        avalidovval: bool,
        bvalidoven: bool,
        bvalidovval: bool,
        hstnegscs: bool,
        hnpreq: bool,
        HostSetHnpEnable: bool,
        devhnpen: bool,
        _reserved12_15: u4,
        conidsts: bool,
        dbnctime: u1,
        ASessionValid: bool,
        BSessionValid: bool,
        OtgVersion: u1,
        _reserved21: u1,
        multvalidbc: u5,
        chirpen: bool,
        _reserved28_31: u4,
    },
    OtgInterrupt: packed struct {
        _reserved0_1: u2,
        SessionEndDetected: bool,
        _reserved3_7: u5,
        SessionRequestSuccessStatusChange: bool,
        HostNegotiationSuccessStatusChange: bool,
        _reserved10_16: u7,
        HostNegotiationDetected: bool,
        ADeviceTimeoutChange: bool,
        DebounceDone: bool,
        _reserved20_31: u12,
    },
    Ahb: packed struct {
        InterruptEnable: bool,
        // In accordance with the SoC-Peripherals manual, broadcom redefines 
        // the meaning of bits 1:4 in this structure.
        axi_burst_length: u2, // AxiBurstLength
        _reserved3: u1,
        WaitForAxiWrites: bool,
        DmaEnable: bool,
        _reserved6: u1,
        transfer_empty_level: u1, // EmptyLevel
        PeriodicTransferEmptyLevel: u1, // EmptyLevel
        _reserved9_20: u12,
        remmemsupp: bool,
        notialldmawrit: bool,
        dma_remainder_mode: u1, // DmaRemainderMode
        _reserved24_31: u8,
    },
    Usb: packed struct {
        toutcal: u3,
        PhyInterface: bool,
        ModeSelect: u1, // UMode
        fsintf: bool,
        physel: bool,
        ddrsel: bool,
        SrpCapable: bool,
        HnpCapable: bool,
        usbtrdtim: u4,
        reserved1: u1,
        // PHY lower power mode clock select
        phy_lpm_clk_sel: bool,
        otgutmifssel: bool,
        UlpiFsls: bool,
        ulpi_auto_res: bool,
        ulpi_clk_sus_m: bool,
        UlpiDriveExternalVbus: bool,
        ulpi_int_vbus_indicator: bool,
        TsDlinePulseEnable: bool,
        indicator_complement: bool,
        indicator_pass_through: bool,
        ulpi_int_prot_dis: bool,
        ic_usb_capable: bool,
        ic_traffic_pull_remove: bool,
        tx_end_delay: bool,
        force_host_mode: bool,
        force_dev_mode: bool,
        _reserved31: bool,
    },
    Reset: packed struct {
        CoreSoft: bool,
        HclkSoft: bool,
        HostFrameCounter: bool,
        InTokenQueueFlush: bool,
        ReceiveFifoFlush: bool,
        TransmitFifoFlush: bool,
        TransmitFifoFlushNumber: u5, // CoreFifoFlush
        _reserved11_29: u19,
        DmaRequestSignal: bool,
        AhbMasterIdle: bool,
    },
    Interrupt: CoreInterrupts,
    InterruptMask: CoreInterrupts,
    Receive: packed struct {
        Peek: ReceiveStatus, // Read Only +0x1c
        Pop: ReceiveStatus, // Read Only +0x20
        Size: u32,
    },
    NonPeriodicFifo: packed struct {
        Size: FifoSize,
        Status: packed struct {
            SpaceAvailable: u16,
            QueueSpaceAvailable: u8,
            Terminate: u1,
            token_type: u2, // CoreGlobalRegsTokenType
            Channel: u4,
            Odd: u1,
        }, // Read Only +0x2c
    },
    I2cControl: packed struct {
        ReadWriteData: u8,
        RegisterAddress: u8,
        Address: u7,
        I2cEnable: bool,
        Acknowledge: bool,
        I2cSuspendControl: bool,
        I2cDeviceAddress: u2,
        _reserved28_29: u2,
        ReadWrite: bool,
        bsydne: bool,
    },
    PhyVendorControl: u32,
    Gpio: u32,
    UserId: u32,
    VendorId: u32, // Read Only +0x40
    Hardware: packed struct {
        Direction0: u2,
        Direction1: u2,
        Direction2: u2,
        Direction3: u2,
        Direction4: u2,
        Direction5: u2,
        Direction6: u2,
        Direction7: u2,
        Direction8: u2,
        Direction9: u2,
        Direction10: u2,
        Direction11: u2,
        Direction12: u2,
        Direction13: u2,
        Direction14: u2,
        Direction15: u2,
        operating_mode: u3, // OperatingMode
        architecture: u2, // Architecture
        PointToPoint: bool,
        high_speed_physical: u2, // HighSpeedPhysical
        full_speed_physical: u2, // FullSpeedPhysical
        DeviceEndPointCount: u4,
        HostChannelCount: u4,
        SupportsPeriodicEndpoints: bool,
        DynamicFifo: bool,
        multi_proc_int: bool,
        _reserver21: u1,
        NonPeriodicQueueDepth: u2,
        HostPeriodicQueueDepth: u2,
        DeviceTokenQueueDepth: u5,
        EnableIcUsb: bool,
        TransferSizeControlWidth: u4,
        PacketSizeControlWidth: u3,
        otg_func: bool,
        I2c: bool,
        VendorControlInterface: bool,
        OptionalFeatures: bool,
        SynchronousResetType: bool,
        AdpSupport: bool,
        otg_enable_hsic: bool,
        bc_support: bool,
        LowPowerModeEnabled: bool,
        FifoDepth: u16,
        PeriodicInEndpointCount: u4,
        PowerOptimisation: bool,
        MinimumAhbFrequency: bool,
        PartialPowerOff: bool,
        _reserved103_109: u7,
        utmi_physical_data_width: u2, // UtmiPhysicalDataWidth
        ModeControlEndpointCount: u4,
        ValidFilterIddigEnabled: bool,
        VbusValidFilterEnabled: bool,
        ValidFilterAEnabled: bool,
        ValidFilterBEnabled: bool,
        SessionEndFilterEnabled: bool,
        ded_fifo_en: bool,
        InEndpointCount: u4,
        DmaDescription: bool,
        DmaDynamicDescription: bool,
    }, // All read only +0x44
    LowPowerModeConfiguration: packed struct {
        LowPowerModeCapable: bool,
        ApplicationResponse: bool,
        HostInitiatedResumeDuration: u4,
        RemoteWakeupEnabled: bool,
        UtmiSleepEnabled: bool,
        HostInitiatedResumeDurationThreshold: u5,
        LowPowerModeResponse: u2,
        PortSleepStatus: bool,
        SleepStateResumeOk: bool,
        LowPowerModeChannelIndex: u4,
        RetryCount: u3,
        SendLowPowerMode: bool,
        RetryCountStatus: u3,
        _reserved28_29: u2,
        HsicConnect: bool,
        InverseSelectHsic: bool,
    },
    _reserved58_80: [0x80 - 0x58]u8, // No read or write +0x58
    MdioControl: packed struct {
        Read: u16,
        ClockRatio: u4,
        FreeRun: bool,
        BithashEnable: bool,
        MdcWrite: bool,
        MdoWrite: bool,
        _reserved24_30: u7,
        Busy: bool,
    },
    mdio_read_write: u32,
    MiscControl: packed struct {
        SessionEnd: bool,
        VbusValid: bool,
        BSessionValid: bool,
        ASessionValid: bool,
        DischargeVbus: bool,
        ChargeVbus: bool,
        DriveVbus: bool,
        DisableDriving: bool,
        VbusIrqEnabled: bool,
        VbusIrq: bool,
        _reserved10_15: u6,
        AxiPriorityLevel: u4,
        _reserved20_31: u12,
    },
    _reserved8c_100: [0x100 - 0x8c]u8,
    PeriodicFifo: packed struct {
        HostSize: FifoSize,
        DataSize: [15]FifoSize,
    },
    _reserved140_400: [0x400 - 0x140]u8,
};

const TransactionPosition = enum {
    Middle,
    End,
    Begin,
    All,
};


/// Contains the interrupts that controls the channels of the DesignWare® 
/// Hi-Speed USB 2.0 On-The-Go (HS OTG) Controller.
const ChannelInterrupts = packed struct {
    TransferComplete: bool,
    Halt: bool,
    AhbError: bool,
    Stall: bool,
    NegativeAcknowledgement: bool,
    Acknowledgement: bool,
    NotYet: bool,
    TransactionError: bool,
    BabbleError: bool,
    FrameOverrun: bool,
    DataToggleError: bool,
    BufferNotAvailable: bool,
    ExcessiveTransmission: bool,
    FrameListRollover: bool,
    _reserved14_31: u18,
};

const PacketId = struct {
    const Data0 = 0;
    const Data1 = 2;
    const Data2 = 1;
    const MData = 3;
    const Setup = 3;
};

const HostChannel = packed struct {
    Characteristic: packed struct {
        MaximumPacketSize: u11,
        EndPointNumber: u4,
        EndPointDirection: u1, // UsbDirection
        _reserved16: u1,
        LowSpeed: bool,
        transfer_type: u2, // UsbTransfer
        PacketsPerFrame: u2,
        DeviceAddress: u7,
        OddFrame: u1,
        Disable: bool,
        Enable: bool,
    },
    SplitControl: packed struct {
        PortAddress: u7,
        HubAddress: u7,
        transaction_position: u2, // TransactionPosition
        CompleteSplit: bool,
        _reserved17_30: u14,
        SplitEnable: bool,
    },
    Interrupt: ChannelInterrupts,
    InterruptMask: ChannelInterrupts,
    TransferSize: packed struct {
        TransferSize: u19,
        PacketCount: u10,
        packet_id: u2, // PacketId
        DoPing: bool,
    },
    DmaAddress: &u8,
    _reserved18: u32, // +0x18
    _reserved1c: u32, // +0x1c
};

const ClockRate = enum {
    Clock30_60MHz,
    Clock48MHz,
    Clock6MHz,
};

const ChannelCount = 16;

/// Contains the host mode global registers structure that controls the DesignWare®
/// Hi-Speed USB 2.0 On-The-Go (HS OTG) Controller.
const HostGlobalRegs = packed struct {
    Config: packed struct {
        clock_rate: u2,
        FslsOnly: bool,
        _reserved3_6: u4,
        en_32khz_susp: u1,
        res_val_period: u8,
        _reserved16_22: u7,
        EnableDmaDescriptor: bool,
        FrameListEntries: u2,
        PeriodicScheduleEnable: bool,
        PeriodicScheduleStatus: bool,
        reserved28_30: u3,
        mode_chg_time: bool,
    },
    FrameInterval: packed struct {
        Interval: u16,
        DynamicFrameReload: bool,
        _reserved17_31: u15,
    },
    FrameNumber: packed struct {
        FrameNumber: u16,
        FrameRemaining: u16,
    },
    _reserved40c: u32, // + 0x40c
    FifoStatus: packed struct {
        SpaceAvailable: u16,
        QueueSpaceAvailable: u8,
        Terminate: u1,
        token_type: u2, // HostGlobalRegsTokenType
        Channel: u4,
        Odd: u1,
    },
    Interrupt: u32,
    InterruptMask: u32,
    FrameList: u32,
    _reserved420_440: [0x440 - 0x420]u8,
    Port: packed struct {
        Connect: bool,
        ConnectDetected: bool,
        Enable: bool,
        EnableChanged: bool,
        OverCurrent: bool,
        OverCurrentChanged: bool,
        Resume: bool,
        Suspend: bool,
        Reset: bool,
        _reserved9: u1,
        PortLineStatus: u2,
        Power: bool,
        TestControl: u4,
        speed: u2, // UsbSpeed
        _reserved19_31: u13,
    },
    _reserved444_500: [0x500 - 0x444]u8,
    Channel: [ChannelCount]HostChannel,
    _reserved700_800: [0x800 - 0x700]u8,
};


/// Contains the dwc power and clock gating structure that controls the DesignWare®
/// Hi-Speed USB 2.0 On-The-Go (HS OTG) Controller.
const PowerReg = packed struct {
    StopPClock: bool,
    GateHClock: bool,
    PowerClamp: bool,
    PowerDownModules: bool,
    PhySuspended: bool,
    EnableSleepClockGating: bool,
    PhySleeping: bool,
    DeepSleep: bool,
    _reserved8_31: u24,
};

const UsbDeviceRequestRequest = struct {
    // USB requests
    const GetStatus = 0;
    const ClearFeature = 1;
    const SetFeature = 3;
    const SetAddress = 5;
    const GetDescriptor = 6;
    const SetDescriptor = 7;
    const GetConfiguration = 8;
    const SetConfiguration = 9;
    const GetInterface = 10;
    const SetInterface = 11;
    const SynchFrame = 12;
    // HID requests
    const GetReport = 1;
    const GetIdle = 2;
    const GetProtocol = 3;
    const SetReport = 9;
    const SetIdle = 10;
    const SetProtocol = 11;
};

/// An encapsulated device request.
///
/// A device request is a standard mechanism defined in USB2.0 manual section
/// 9.3 by which negotiations with devices occur. The request have a number of 
/// parameters, and so are best implemented with a structure. As per usual,
/// since this structure is arbitrary, we shall match Linux in the hopes of 
/// achieving some compatibility.
const UsbDeviceRequest = packed struct {
    Type: u8,
    Request: u8, // UsbDeviceRequestRequest
    Value: u16, // +0x2
    Index: u16, // +0x4
    Length: u16, // +0x6
};

const HCD_DESIGNWARE_BASE: usize = 0x3f980000;

const core_physical = (&volatile CoreGlobalRegs)(HCD_DESIGNWARE_BASE);
var core: CoreGlobalRegs = undefined;

const host_physical = (&volatile HostGlobalRegs)(HCD_DESIGNWARE_BASE + 0x400);
var host: HostGlobalRegs = undefined;

const power_physical = (&volatile PowerReg)(HCD_DESIGNWARE_BASE + 0xe00);
var power: PowerReg = undefined;

fn hcdInitialize() -> %void {
    comptime {
        assert(@sizeOf(CoreGlobalRegs) == 0x400);
        assert(@sizeOf(HostGlobalRegs) == 0x400);
        assert(@sizeOf(PowerReg) == 0x4);
    }

    dumpMemory(usize(core_physical), @sizeOf(CoreGlobalRegs));

    core.VendorId = core_physical.VendorId;
    core.UserId = core_physical.UserId;

    if ((core.VendorId & 0xfffff000) != 0x4f542000) { // 'OT'2 
        log("HCD: Hardware: {c}{c}{x}.{x}{x}{x} (BCM{x5}). Driver incompatible. Expected OT2.xxx (BCM2708x).\n",
            u8((core.VendorId >> 24) & 0xff), u8((core.VendorId >> 16) & 0xff),
            u8((core.VendorId >> 12) & 0xf), u8((core.VendorId >> 8) & 0xf),
            u8((core.VendorId >> 4) & 0xf), u8((core.VendorId >> 0) & 0xf), 
            (core.UserId >> 12) & 0xFFFFF);
        return error.Incompatible;
    } else {
        log("HCD: Hardware: {c}{c}{x}.{x}{x}{x} (BCM{x5}).\n",
            u8((core.VendorId >> 24) & 0xff), u8((core.VendorId >> 16) & 0xff),
            u8((core.VendorId >> 12) & 0xf), u8((core.VendorId >> 8) & 0xf),
            u8((core.VendorId >> 4) & 0xf), u8((core.VendorId >> 0) & 0xf), 
            (core.UserId >> 12) & 0xFFFFF);
    }

    panic("TODO hcdInitialize");

//
//    ReadBackReg(&Core->Hardware);
//    if (Core->Hardware.Architecture != InternalDma) {
//        LOG("HCD: Host architecture is not Internal DMA. Driver incompatible.\n");
//        result = ErrorIncompatible;
//        goto deallocate;
//    }
//    LOG_DEBUG("HCD: Internal DMA mode.\n");
//    if (Core->Hardware.HighSpeedPhysical == NotSupported) {
//        LOG("HCD: High speed physical unsupported. Driver incompatible.\n");
//        result = ErrorIncompatible;
//        goto deallocate;
//    }
//    LOG_DEBUGF("HCD: Hardware configuration: %08x %08x %08x %08x\n", *(u32*)&Core->Hardware, *((u32*)&Core->Hardware + 1), *((u32*)&Core->Hardware + 2), *((u32*)&Core->Hardware + 3));
//    ReadBackReg(&Host->Config);
//    LOG_DEBUGF("HCD: Host configuration: %08x\n", *(u32*)&Host->Config);
//    
//    LOG_DEBUG("HCD: Disabling interrupts.\n");
//    ReadBackReg(&Core->Ahb);
//    Core->Ahb.InterruptEnable = false;
//    ClearReg(&Core->InterruptMask);
//    WriteThroughReg(&Core->InterruptMask);
//    WriteThroughReg(&Core->Ahb);
//    
//    LOG_DEBUG("HCD: Powering USB on.\n");
//    if ((result = PowerOnUsb()) != OK) {
//        LOG("HCD: Failed to power on USB Host Controller.\n");
//        result = ErrorIncompatible;
//        goto deallocate;
//    }
//    
//    LOG_DEBUG("HCD: Load completed.\n");
//
//    return OK;
}

fn hcdDeinitialize() {
    panic("TODO hcdDeinitialize");
}

fn hidAttach(device: &UsbDevice, interface_number: u32) -> %void {
    if (device.interfaces[interface_number].class != InterfaceClass.Hid)
        return error.Argument;

    if (device.interfaces[interface_number].endpoint_count < 1) {
        log("HID: Invalid HID device with fewer than one endpoints ({}).\n",
            device.interfaces[interface_number].endpoint_count);
        return error.Incompatible;
    }
    
    if (UsbDirection(device.endpoints[interface_number].endpoint_address.direction) != UsbDirection.DeviceToHost ||
        UsbTransfer(device.endpoints[interface_number].attributes.transfer_type) != UsbTransfer.Interrupt)
    {
        log("HID: Invalid HID device with unusual endpoints (0).\n");
        return error.Incompatible;
    }

    log("so far so good - TODO more HidAttach");
}

//Result HidAttach(struct UsbDevice *device, u32 interfaceNumber) {
//    struct HidDevice *data;
//    struct HidDescriptor *descriptor;
//    struct UsbDescriptorHeader *header;
//    void* reportDescriptor = NULL;
//    Result result;
//    u32 currentInterface;
//
//    if (device->Interfaces[interfaceNumber].EndpointCount >= 2) {
//        if (device->Endpoints[interfaceNumber][1].EndpointAddress.Direction != Out ||
//            device->Endpoints[interfaceNumber][1].Attributes.Type != Interrupt) {
//            LOG("HID: Invalid HID device with unusual endpoints (1).\n");
//            return ErrorIncompatible;
//        }    
//    }
//    if (device->Status != Configured) {
//        LOG("HID: Cannot start driver on unconfigured device!\n");
//        return ErrorDevice;
//    }
//    if (device->Interfaces[interfaceNumber].SubClass == 1) {
//        if (device->Interfaces[interfaceNumber].Protocol == 1)
//            LOG_DEBUG("HID: Boot keyboard detected.\n");
//        else if (device->Interfaces[interfaceNumber].Protocol == 2)
//            LOG_DEBUG("HID: Boot mouse detected.\n");
//        else 
//            LOG_DEBUG("HID: Unknown boot device detected.\n");
//        
//        LOG_DEBUG("HID: Reverting from boot to normal HID mode.\n");
//        if ((result = HidSetProtocol(device, interfaceNumber, 1)) != OK) {
//            LOG("HID: Could not revert to report mode from HID mode.\n");
//            return result;
//        }
//    }
//
//    header = (struct UsbDescriptorHeader*)device->FullConfiguration;
//    descriptor = NULL;
//    currentInterface = interfaceNumber + 1; // Certainly different!
//    do {        
//        if (header->DescriptorLength == 0) break; // List end
//        switch (header->DescriptorType) {
//        case Interface:
//            currentInterface = ((struct UsbInterfaceDescriptor*)header)->Number;
//            break;
//        case Hid:
//            if (currentInterface == interfaceNumber)
//                descriptor = (void*)header;
//            break;
//        default:
//            break;
//        }
//        
//        LOG_DEBUGF("HID: Descriptor %d length %d, interface %d.\n", header->DescriptorType, header->DescriptorLength, currentInterface);
//
//        if (descriptor != NULL) break;
//        header = (void*)((u8*)header + header->DescriptorLength);
//    } while (true);
//
//    if (descriptor == NULL) {
//        LOGF("HID: No HID descriptor in %s.Interface%d. Cannot be a HID device.\n", UsbGetDescription(device), interfaceNumber + 1);
//        return ErrorIncompatible;
//    }
//
//    if (descriptor->HidVersion > 0x111) {
//        LOGF("HID: Device uses unsupported HID version %x.%x.\n", descriptor->HidVersion >> 8, descriptor->HidVersion & 0xff);
//        return ErrorIncompatible;
//    }
//    LOG_DEBUGF("HID: Device version HID %x.%x.\n", descriptor->HidVersion >> 8, descriptor->HidVersion & 0xff);
//    
//    device->DeviceDeallocate = HidDeallocate;
//    device->DeviceDetached = HidDetached;
//    if ((device->DriverData = MemoryAllocate(sizeof (struct HidDevice))) == NULL) {
//        result = ErrorMemory;
//        goto deallocate;
//    }
//    device->DriverData->DataSize = sizeof(struct HidDevice);
//    device->DriverData->DeviceDriver = DeviceDriverHid;
//    data = (struct HidDevice*)device->DriverData;
//    data->Descriptor = descriptor;
//    data->DriverData = NULL;
//    
//    if ((reportDescriptor = MemoryAllocate(descriptor->OptionalDescriptors[0].Length)) == NULL) {
//        result = ErrorMemory;
//        goto deallocate;
//    }
//    if ((result = UsbGetDescriptor(device, HidReport, 0, interfaceNumber, reportDescriptor, descriptor->OptionalDescriptors[0].Length, descriptor->OptionalDescriptors[0].Length, 1)) != OK) {
//        MemoryDeallocate(reportDescriptor);
//        LOGF("HID: Could not read report descriptor for %s.Interface%d.\n", UsbGetDescription(device), interfaceNumber + 1);
//        goto deallocate;
//    }
//    if ((result = HidParseReportDescriptor(device, reportDescriptor, descriptor->OptionalDescriptors[0].Length)) != OK) {        
//        MemoryDeallocate(reportDescriptor);
//        LOGF("HID: Invalid report descriptor for %s.Interface%d.\n", UsbGetDescription(device), interfaceNumber + 1);
//        goto deallocate;
//    }
//
//    MemoryDeallocate(reportDescriptor);
//    reportDescriptor = NULL;
//
//    data->ParserResult->Interface = interfaceNumber;
//    if (data->ParserResult->Application.Page == GenericDesktopControl &&
//        (u16)data->ParserResult->Application.Desktop < HidUsageAttachCount &&
//        HidUsageAttach[(u16)data->ParserResult->Application.Desktop] != NULL) {
//        HidUsageAttach[(u16)data->ParserResult->Application.Desktop](device, interfaceNumber);
//    }
//
//    return OK;
//deallocate:
//    if (reportDescriptor != NULL) MemoryDeallocate(reportDescriptor);
//    HidDeallocate(device);
//    return result;
//}
