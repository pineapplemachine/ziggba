//! This module contains rudimentary definitions indicating the location
//! in memory of each of the system's hardware registers.
//!
//! Note that more usable APIs exist in ZigGBA for accessing nearly all of
//! these registers. These are intended primarily for internal use by ZigGBA,
//! but are also made externally available for advanced users.
//!
//! Names are the same as in Tonc (`tonc_memmap.h`).

const gba = @import("gba.zig");
const io_address = gba.mem.io_address;

/// REG_IFBIOS. See `gba.interrupt.irq_ack_bios`.
/// Not really a hardware register. Located in IWRAM, not MMIO.
pub const reg_ifbios: *volatile u16 = @ptrFromInt(io_address - 0x0008);

/// REG_RESET_DST.
/// Not really a hardware register. Located in IWRAM, not MMIO.
pub const reg_reset_dst: *volatile u16 = @ptrFromInt(io_address - 0x0006);

/// REG_ISR_MAIN. See `gba.interrupt.isr_ptr`.
/// ZigGBA initializes this register to point to a default master ISR
/// `gba.interrupt.isr_default` which then calls whatever function pointer
/// is stored at `gba.interrupt.isr_default_redirect`.
/// Not really a hardware register. Located in IWRAM, not MMIO.
pub const reg_isr_main: *volatile u32 = @ptrFromInt(io_address - 0x0004);

/// REG_DISPCNT. See `gba.display.ctrl`.
pub const reg_dispcnt: *volatile u32 = @ptrFromInt(io_address + 0x0000);

/// REG_DISPSTAT. See `gba.display.status`.
pub const reg_dispstat: *volatile u16 = @ptrFromInt(io_address + 0x0004);

/// REG_VCOUNT. See `gba.display.vcount`.
pub const reg_vcount: *volatile u16 = @ptrFromInt(io_address + 0x0006);

/// REG_BGCNT. See also `gba.bg.ctrl`.
pub const reg_bgcnt: *volatile [4]u16 = @ptrFromInt(io_address + 0x0008);

/// REG_BG0CNT. See also `gba.bg.ctrl[0]`.
pub const reg_bg0cnt: *volatile u16 = @ptrFromInt(io_address + 0x0008);

/// REG_BG1CNT. See also `gba.bg.ctrl[1]`.
pub const reg_bg1cnt: *volatile u16 = @ptrFromInt(io_address + 0x000a);

/// REG_BG2CNT. See also `gba.bg.ctrl[2]`.
pub const reg_bg2cnt: *volatile u16 = @ptrFromInt(io_address + 0x000c);

/// REG_BG3CNT. See also `gba.bg.ctrl[3]`.
pub const reg_bg3cnt: *volatile u16 = @ptrFromInt(io_address + 0x000e);

/// REG_BG_OFS. See also `gba.bg.scroll`.
pub const reg_bg_ofs: *volatile [4][2]u16 = @ptrFromInt(io_address + 0x0010);

/// REG_BG0HOFS. See also `gba.bg.scroll[0].x`.
pub const reg_bg0hofs: *volatile u16 = @ptrFromInt(io_address + 0x0010);

/// REG_BG0VOFS. See also `gba.bg.scroll[0].y`.
pub const reg_bg0vofs: *volatile u16 = @ptrFromInt(io_address + 0x0012);

/// REG_BG1HOFS. See also `gba.bg.scroll[1].x`.
pub const reg_bg1hofs: *volatile u16 = @ptrFromInt(io_address + 0x0014);

/// REG_BG1VOFS. See also `gba.bg.scroll[1].y`.
pub const reg_bg1vofs: *volatile u16 = @ptrFromInt(io_address + 0x0016);

/// REG_BG2HOFS. See also `gba.bg.scroll[2].x`.
pub const reg_bg2hofs: *volatile u16 = @ptrFromInt(io_address + 0x0018);

/// REG_BG2VOFS. See also `gba.bg.scroll[2].y`.
pub const reg_bg2vofs: *volatile u16 = @ptrFromInt(io_address + 0x001a);

/// REG_BG3HOFS. See also `gba.bg.scroll[3].x`.
pub const reg_bg3hofs: *volatile u16 = @ptrFromInt(io_address + 0x001c);

/// REG_BG3VOFS. See also `gba.bg.scroll[3].y`.
pub const reg_bg3vofs: *volatile u16 = @ptrFromInt(io_address + 0x001e);

/// Represents the memory layout of `reg_bg_affine` items.
/// See also `gba.math.Affine3x2`.
pub const RegBgAffine = extern struct {
    pa: i16,
    pb: i16,
    pc: i16,
    pd: i16,
    x: i32,
    y: i32,
};

/// REG_BG_AFFINE. See `gba.display.bg_affine`.
pub const reg_bg_affine: *volatile [2]RegBgAffine = @ptrFromInt(io_address + 0x0020);

/// REG_BG2PA. See `gba.display.bg_2_affine.abcd.a`.
pub const reg_bg2pa: *volatile i16 = @ptrFromInt(io_address + 0x0020);

/// REG_BG2PB. See `gba.display.bg_2_affine.abcd.b`.
pub const reg_bg2pb: *volatile i16 = @ptrFromInt(io_address + 0x0022);

/// REG_BG2PC. See `gba.display.bg_2_affine.abcd.c`.
pub const reg_bg2pc: *volatile i16 = @ptrFromInt(io_address + 0x0024);

/// REG_BG2PD. See `gba.display.bg_2_affine.abcd.d`.
pub const reg_bg2pd: *volatile i16 = @ptrFromInt(io_address + 0x0026);

/// REG_BG2X. See `gba.display.bg_2_affine.disp.x`.
pub const reg_bg2x: *volatile i32 = @ptrFromInt(io_address + 0x0028);

/// REG_BG2Y. See `gba.display.bg_2_affine.disp.y`.
pub const reg_bg2y: *volatile i32 = @ptrFromInt(io_address + 0x002c);

/// REG_BG3PA. See `gba.display.bg_3_affine.abcd.a`.
pub const reg_bg3pa: *volatile i16 = @ptrFromInt(io_address + 0x0030);

/// REG_BG3PB. See `gba.display.bg_3_affine.abcd.b`.
pub const reg_bg3pb: *volatile i16 = @ptrFromInt(io_address + 0x0032);

/// REG_BG3PC. See `gba.display.bg_3_affine.abcd.c`.
pub const reg_bg3pc: *volatile i16 = @ptrFromInt(io_address + 0x0034);

/// REG_BG3PD. See `gba.display.bg_3_affine.abcd.d`.
pub const reg_bg3pd: *volatile i16 = @ptrFromInt(io_address + 0x0036);

/// REG_BG3X. See `gba.display.bg_3_affine.disp.x`.
pub const reg_bg3x: *volatile i32 = @ptrFromInt(io_address + 0x0038);

/// REG_BG3Y. See `gba.display.bg_3_affine.disp.y`.
pub const reg_bg3y: *volatile i32 = @ptrFromInt(io_address + 0x003c);

/// REG_WIN0H. See `gba.display.window.bounds_x[0]`.
pub const reg_win0h: *volatile u16 = @ptrFromInt(io_address + 0x0040);

/// REG_WIN1H. See `gba.display.window.bounds_x[1]`.
pub const reg_win1h: *volatile u16 = @ptrFromInt(io_address + 0x0042);

/// REG_WIN0V. See `gba.display.window.bounds_y[0]`.
pub const reg_win0v: *volatile u16 = @ptrFromInt(io_address + 0x0044);

/// REG_WIN1V. See `gba.display.window.bounds_y[1]`.
pub const reg_win1v: *volatile u16 = @ptrFromInt(io_address + 0x0046);

/// REG_WININ. See `gba.display.window.inner`.
pub const reg_winin: *volatile u16 = @ptrFromInt(io_address + 0x0048);

/// REG_WINOUT. See `gba.display.window.other`.
pub const reg_winout: *volatile u16 = @ptrFromInt(io_address + 0x004a);

/// REG_WIN0R. See `gba.display.window.bounds_x[0].right`.
pub const reg_win0r: *volatile u8 = @ptrFromInt(io_address + 0x0040);

/// REG_WIN0L. See `gba.display.window.bounds_x[0].left`.
pub const reg_win0l: *volatile u8 = @ptrFromInt(io_address + 0x0041);

/// REG_WIN1R. See `gba.display.window.bounds_x[1].right`.
pub const reg_win1r: *volatile u8 = @ptrFromInt(io_address + 0x0042);

/// REG_WIN1L. See `gba.display.window.bounds_x[1].left`.
pub const reg_win1l: *volatile u8 = @ptrFromInt(io_address + 0x0043);

/// REG_WIN0B. See `gba.display.window.bounds_y[0].bottom`.
pub const reg_win0b: *volatile u8 = @ptrFromInt(io_address + 0x0044);

/// REG_WIN0T. See `gba.display.window.bounds_y[0].top`.
pub const reg_win0t: *volatile u8 = @ptrFromInt(io_address + 0x0045);

/// REG_WIN1B. See `gba.display.window.bounds_y[1].bottom`.
pub const reg_win1b: *volatile u8 = @ptrFromInt(io_address + 0x0046);

/// REG_WIN1T. See `gba.display.window.bounds_y[1].top`.
pub const reg_win1t: *volatile u8 = @ptrFromInt(io_address + 0x0047);

/// REG_WIN0CNT. See `gba.display.window.inner.win0`.
pub const reg_win0cnt: *volatile u8 = @ptrFromInt(io_address + 0x0048);

/// REG_WIN1CNT. See `gba.display.window.inner.win1`.
pub const reg_win1cnt: *volatile u8 = @ptrFromInt(io_address + 0x0049);

/// REG_WINOUTCNT. See `gba.display.window.other.outer`.
pub const reg_winoutcnt: *volatile u8 = @ptrFromInt(io_address + 0x004a);

/// REG_WINOBJCNT. See `gba.display.window.other.obj`.
pub const reg_winobjcnt: *volatile u8 = @ptrFromInt(io_address + 0x004b);

/// REG_MOSAIC. See `gba.display.mosaic`.
pub const reg_mosaic: *volatile u32 = @ptrFromInt(io_address + 0x004c);

/// REG_BLDCNT. See `gba.display.blend.ctrl`.
pub const reg_bldcnt: *volatile u16 = @ptrFromInt(io_address + 0x0050);

/// REG_BLDALPHA. See `gba.display.blend.alpha`.
pub const reg_bldalpha: *volatile u16 = @ptrFromInt(io_address + 0x0052);

/// REG_BLDY. See `gba.display.blend.luma`.
pub const reg_bldy: *volatile u16 = @ptrFromInt(io_address + 0x0054);

/// REG_SND1SWEEP. See `gba.sound.pulse_1.sweep`.
pub const reg_snd1sweep: *volatile u16 = @ptrFromInt(io_address + 0x0060);

/// REG_SND1CNT. See `gba.sound.pulse_1.ctrl`.
pub const reg_snd1cnt: *volatile u16 = @ptrFromInt(io_address + 0x0062);

/// REG_SND1FREQ. See `gba.sound.pulse_1.freq`.
pub const reg_snd1freq: *volatile u16 = @ptrFromInt(io_address + 0x0064);

/// REG_SND2CNT. See `gba.sound.pulse_2.ctrl`.
pub const reg_snd2cnt: *volatile u16 = @ptrFromInt(io_address + 0x0068);

/// REG_SND2FREQ. See `gba.sound.pulse_2.freq`.
pub const reg_snd2freq: *volatile u16 = @ptrFromInt(io_address + 0x006c);

/// REG_SND3SEL. See `gba.sound.wave.select`.
pub const reg_snd3sel: *volatile u16 = @ptrFromInt(io_address + 0x0070);

/// REG_SND3CNT. See `gba.sound.wave.ctrl`.
pub const reg_snd3cnt: *volatile u16 = @ptrFromInt(io_address + 0x0072);

/// REG_SND3FREQ. See `gba.sound.wave.freq`.
pub const reg_snd3freq: *volatile u16 = @ptrFromInt(io_address + 0x0074);

/// REG_SND4CNT. See `gba.sound.noise.ctrl`.
pub const reg_snd4cnt: *volatile u16 = @ptrFromInt(io_address + 0x0078);

/// REG_SND4FREQ. See `gba.sound.noise.freq`.
pub const reg_snd4freq: *volatile u16 = @ptrFromInt(io_address + 0x007c);

/// REG_SNDCNT. See `gba.sound.ctrl`.
pub const reg_sndcnt: *volatile u32 = @ptrFromInt(io_address + 0x0080);

/// REG_SNDDMGCNT. See `gba.sound.ctrl.dmg`.
pub const reg_snddmgcnt: *volatile u16 = @ptrFromInt(io_address + 0x0080);

/// REG_SNDDSCNT. See `gba.sound.ctrl.dsound`.
pub const reg_snddscnt: *volatile u16 = @ptrFromInt(io_address + 0x0082);

/// REG_SNDSTAT. See `gba.sound.status`.
pub const reg_sndstat: *volatile u16 = @ptrFromInt(io_address + 0x0084);

/// REG_SNDBIAS. See `gba.sound.bias`.
pub const reg_sndbias: *volatile u16 = @ptrFromInt(io_address + 0x0088);

/// REG_WAVE_RAM. See `gba.sound.wave_ram`.
pub const reg_wave_ram: *volatile [4]u32 = @ptrFromInt(io_address + 0x0090);

/// REG_WAVE_RAM0. See `gba.sound.wave_ram[0]`.
pub const reg_wave_ram0: *volatile u32 = @ptrFromInt(io_address + 0x0090);

/// REG_WAVE_RAM1. See `gba.sound.wave_ram[1]`.
pub const reg_wave_ram1: *volatile u32 = @ptrFromInt(io_address + 0x0094);

/// REG_WAVE_RAM2. See `gba.sound.wave_ram[2]`.
pub const reg_wave_ram2: *volatile u32 = @ptrFromInt(io_address + 0x0098);

/// REG_WAVE_RAM3. See `gba.sound.wave_ram[3]`.
pub const reg_wave_ram3: *volatile u32 = @ptrFromInt(io_address + 0x009c);

/// REG_FIFO_A. See `gba.sound.fifo_a`.
pub const reg_fifo_a: *volatile u32 = @ptrFromInt(io_address + 0x00a0);

/// REG_FIFO_B. See `gba.sound.fifo_b`.
pub const reg_fifo_b: *volatile u32 = @ptrFromInt(io_address + 0x00a4);

/// Represents the memory layout of `reg_dma` items.
/// See also `gba.mem.Dma`.
pub const RegDma = extern struct {
    sad: u32,
    dad: u32,
    cnt: u32,
};

/// REG_DMA. See `gba.mem.dma`.
pub const reg_dma: *volatile [3]RegDma = @ptrFromInt(io_address + 0x00b0);

/// REG_DMA0SAD. See `gba.mem.dma[0].source`.
pub const reg_dma0sad: *volatile u32 = @ptrFromInt(io_address + 0x00b0);

/// REG_DMA0DAD. See `gba.mem.dma[0].dest`.
pub const reg_dma0dad: *volatile u32 = @ptrFromInt(io_address + 0x00b4);

/// REG_DMA0CNT. See `gba.mem.dma[0].count` and `gba.mem.dma[0].ctrl`.
pub const reg_dma0cnt: *volatile u32 = @ptrFromInt(io_address + 0x00b8);

/// REG_DMA1SAD. See `gba.mem.dma[1].source`.
pub const reg_dma1sad: *volatile u32 = @ptrFromInt(io_address + 0x00bc);

/// REG_DMA1DAD. See `gba.mem.dma[1].dest`.
pub const reg_dma1dad: *volatile u32 = @ptrFromInt(io_address + 0x00c0);

/// REG_DMA1CNT. See `gba.mem.dma[1].count` and `gba.mem.dma[1].ctrl`.
pub const reg_dma1cnt: *volatile u32 = @ptrFromInt(io_address + 0x00c4);

/// REG_DMA2SAD. See `gba.mem.dma[2].source`.
pub const reg_dma2sad: *volatile u32 = @ptrFromInt(io_address + 0x00c8);

/// REG_DMA2DAD. See `gba.mem.dma[2].dest`.
pub const reg_dma2dad: *volatile u32 = @ptrFromInt(io_address + 0x00cc);

/// REG_DMA2CNT. See `gba.mem.dma[2].count` and `gba.mem.dma[2].ctrl`.
pub const reg_dma2cnt: *volatile u32 = @ptrFromInt(io_address + 0x00d0);

/// REG_DMA3SAD. See `gba.mem.dma[3].source`.
pub const reg_dma3sad: *volatile u32 = @ptrFromInt(io_address + 0x00d4);

/// REG_DMA3DAD. See `gba.mem.dma[3].dest`.
pub const reg_dma3dad: *volatile u32 = @ptrFromInt(io_address + 0x00d8);

/// REG_DMA3CNT. See `gba.mem.dma[3].count` and `gba.mem.dma[3].ctrl`.
pub const reg_dma3cnt: *volatile u32 = @ptrFromInt(io_address + 0x00dc);

/// Represents the memory layout of `reg_tm` items.
/// See also `gba.Timer`.
pub const RegTm = extern struct {
    /// Timer data.
    d: u16,
    /// Timer control.
    cnt: u16,
};

/// REG_TM. See `gba.timers`.
pub const reg_tm: *volatile [4]RegTm = @ptrFromInt(io_address + 0x0100);

/// REG_TM0D. See `gba.timers[0].counter`.
pub const reg_tm0d: *volatile u16 = @ptrFromInt(io_address + 0x0100);

/// REG_TM0CNT. See `gba.timers[0].ctrl`.
pub const reg_tm0cnt: *volatile u16 = @ptrFromInt(io_address + 0x0102);

/// REG_TM1D. See `gba.timers[1].counter`.
pub const reg_tm1d: *volatile u16 = @ptrFromInt(io_address + 0x0104);

/// REG_TM1CNT. See `gba.timers[1].ctrl`.
pub const reg_tm1cnt: *volatile u16 = @ptrFromInt(io_address + 0x0106);

/// REG_TM2D. See `gba.timers[2].counter`.
pub const reg_tm2d: *volatile u16 = @ptrFromInt(io_address + 0x0108);

/// REG_TM2CNT. See `gba.timers[2].ctrl`.
pub const reg_tm2cnt: *volatile u16 = @ptrFromInt(io_address + 0x010a);

/// REG_TM3D. See `gba.timers[3].counter`.
pub const reg_tm3d: *volatile u16 = @ptrFromInt(io_address + 0x010c);

/// REG_TM3CNT. See `gba.timers[3].ctrl`.
pub const reg_tm3cnt: *volatile u16 = @ptrFromInt(io_address + 0x010e);

/// REG_SIOCNT
pub const reg_siocnt: *volatile u16 = @ptrFromInt(io_address + 0x0128);

/// REG_SIODATA
pub const reg_siodata: *volatile u32 = @ptrFromInt(io_address + 0x0120);

/// REG_SIODATA32
pub const reg_siodata32: *volatile u32 = @ptrFromInt(io_address + 0x0120);

/// REG_SIODATA8
pub const reg_siodata8: *volatile u16 = @ptrFromInt(io_address + 0x012a);

/// REG_SIOMULTI
pub const reg_siomulti: *volatile [4]u16 = @ptrFromInt(io_address + 0x0120);

/// REG_SIOMULTI0
pub const reg_siomulti0: *volatile u16 = @ptrFromInt(io_address + 0x0120);

/// REG_SIOMULTI1
pub const reg_siomulti1: *volatile u16 = @ptrFromInt(io_address + 0x0122);

/// REG_SIOMULTI2
pub const reg_siomulti2: *volatile u16 = @ptrFromInt(io_address + 0x0124);

/// REG_SIOMULTI3
pub const reg_siomulti3: *volatile u16 = @ptrFromInt(io_address + 0x0126);

/// REG_SIOMLT_RECV
pub const reg_siomlt_recv: *volatile u16 = @ptrFromInt(io_address + 0x0120);

/// REG_SIOMLT_SEND
pub const reg_siomlt_send: *volatile u16 = @ptrFromInt(io_address + 0x012a);

/// REG_KEYINPUT. See `gba.input.state`.
pub const reg_keyinput: *volatile u16 = @ptrFromInt(io_address + 0x0130);

/// REG_KEYCNT. See `gba.input.interrupt`.
pub const reg_keycnt: *volatile u16 = @ptrFromInt(io_address + 0x0132);

/// REG_RCNT
pub const reg_rcnt: *volatile u16 = @ptrFromInt(io_address + 0x0134);

/// REG_JOYCNT
pub const reg_joycnt: *volatile u16 = @ptrFromInt(io_address + 0x0140);

/// REG_JOY_RECV
pub const reg_joy_recv: *volatile u32 = @ptrFromInt(io_address + 0x0150);

/// REG_JOY_TRANS
pub const reg_joy_trans: *volatile u32 = @ptrFromInt(io_address + 0x0154);

/// REG_JOYSTAT
pub const reg_joystat: *volatile u16 = @ptrFromInt(io_address + 0x0158);

/// REG_IE. See `gba.interrupt.enable`.
pub const reg_ie: *volatile u16 = @ptrFromInt(io_address + 0x0200);

/// REG_IF. See `gba.interrupt.irq_ack`.
pub const reg_if: *volatile u16 = @ptrFromInt(io_address + 0x0202);

/// REG_WAITCNT. See `gba.mem.wait_ctrl`.
pub const reg_waitcnt: *volatile u16 = @ptrFromInt(io_address + 0x0204);

/// REG_IME. See `gba.interrupt.master`.
pub const reg_ime: *volatile u16 = @ptrFromInt(io_address + 0x0208);

/// REG_PAUSE
pub const reg_pause: *volatile u16 = @ptrFromInt(io_address + 0x0300);

/// REG_BLDMOD. (Alternate name for REG_BLDCNT.)
pub const reg_bldmod: *volatile u16 = @ptrFromInt(io_address + 0x0050);

/// REG_COLEV. (Alternate name for REG_BLDALPHA.)
pub const reg_colev: *volatile u16 = @ptrFromInt(io_address + 0x0052);

/// REG_COLEY. (Alternate name for REG_BLDY.)
pub const reg_coley: *volatile u16 = @ptrFromInt(io_address + 0x0054);

/// REG_SOUND1CNT (belogic/GBATEK)
pub const reg_sound1cnt: *volatile u32 = @ptrFromInt(io_address + 0x0060);

/// REG_SOUND1CNT_L (Alternate name for REG_SND1SWEEP in belogic and GBATEK)
pub const reg_sound1cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0060);

/// REG_SOUND1CNT_H (Alternate name for REG_SND1CNT in belogic and GBATEK)
pub const reg_sound1cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x0062);

/// REG_SOUND1CNT_X (Alternate name for REG_SND1FREQ in belogic and GBATEK)
pub const reg_sound1cnt_x: *volatile u16 = @ptrFromInt(io_address + 0x0064);

/// REG_SOUND2CNT_L (Alternate name for REG_SND2CNT in belogic and GBATEK)
pub const reg_sound2cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0068);

/// REG_SOUND2CNT_H (Alternate name for REG_SND2FREQ in belogic and GBATEK)
pub const reg_sound2cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x006c);

/// REG_SOUND3CNT (belogic/GBATEK)
pub const reg_sound3cnt: *volatile u32 = @ptrFromInt(io_address + 0x0070);

/// REG_SOUND3CNT_L (Alternate name for REG_SND3SEL in belogic and GBATEK)
pub const reg_sound3cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0070);

/// REG_SOUND3CNT_H (Alternate name for REG_SND3CNT in belogic and GBATEK)
pub const reg_sound3cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x0072);

/// REG_SOUND3CNT_X (Alternate name for REG_SND3FREQ in belogic and GBATEK)
pub const reg_sound3cnt_x: *volatile u16 = @ptrFromInt(io_address + 0x0074);

/// REG_SOUND4CNT_L (Alternate name for REG_SND4CNT in belogic and GBATEK)
pub const reg_sound4cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0078);

/// REG_SOUND4CNT_H (Alternate name for REG_SND4FREQ in belogic and GBATEK)
pub const reg_sound4cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x007c);

/// REG_SOUNDCNT (Alternate name for REG_SNDCNT in belogic and GBATEK)
pub const reg_soundcnt: *volatile u32 = @ptrFromInt(io_address + 0x0080);

/// REG_SOUNDCNT_L (Alternate name for REG_SNDDMGCNT in belogic and GBATEK)
pub const reg_soundcnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0080);

/// REG_SOUNDCNT_H (Alternate name for REG_SNDDSCNT in belogic and GBATEK)
pub const reg_soundcnt_h: *volatile u16 = @ptrFromInt(io_address + 0x0082);

/// REG_SOUNDCNT_X (Alternate name for REG_SNDSTAT in belogic and GBATEK)
pub const reg_soundcnt_x: *volatile u16 = @ptrFromInt(io_address + 0x0084);

/// REG_SOUNDBIAS (Alternate name for REG_SNDBIAS in belogic and GBATEK)
pub const reg_soundbias: *volatile u16 = @ptrFromInt(io_address + 0x0088);

/// REG_WAVE (Alternate name for REG_WAVE_RAM in belogic and GBATEK)
pub const reg_wave: *volatile [4]u32 = @ptrFromInt(io_address + 0x0090);

/// REG_FIFOA (Alternate name for REG_FIFO_A in belogic and GBATEK)
pub const reg_fifoa: *volatile u32 = @ptrFromInt(io_address + 0x00a0);

/// REG_FIFOB (Alternate name for REG_FIFO_B in belogic and GBATEK)
pub const reg_fifob: *volatile u32 = @ptrFromInt(io_address + 0x00a4);

/// REG_DMA0CNT_L (belogic/GBATEK)
pub const reg_dma0cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x00b8);

/// REG_DMA0CNT_H (belogic/GBATEK)
pub const reg_dma0cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x00ba);

/// REG_DMA1CNT_L (belogic/GBATEK)
pub const reg_dma1cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x00c4);

/// REG_DMA1CNT_H (belogic/GBATEK)
pub const reg_dma1cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x00c6);

/// REG_DMA2CNT_L (belogic/GBATEK)
pub const reg_dma2cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x00d0);

/// REG_DMA2CNT_H (belogic/GBATEK)
pub const reg_dma2cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x00d2);

/// REG_DMA3CNT_L (belogic/GBATEK)
pub const reg_dma3cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x00dc);

/// REG_DMA3CNT_H (belogic/GBATEK)
pub const reg_dma3cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x00de);

/// REG_TM0CNT_L (Alternate name for REG_TM0D in belogic and GBATEK)
pub const reg_tm0cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0100);

/// REG_TM0CNT_H (Alternate name for REG_TM0CNT in belogic and GBATEK)
pub const reg_tm0cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x0102);

/// REG_TM1CNT_L (Alternate name for REG_TM1D in belogic and GBATEK)
pub const reg_tm1cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0104);

/// REG_TM1CNT_H (Alternate name for REG_TM1CNT in belogic and GBATEK)
pub const reg_tm1cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x0106);

/// REG_TM2CNT_L (Alternate name for REG_TM2D in belogic and GBATEK)
pub const reg_tm2cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0108);

/// REG_TM2CNT_H (Alternate name for REG_TM2CNT in belogic and GBATEK)
pub const reg_tm2cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x010a);

/// REG_TM3CNT_L (Alternate name for REG_TM3D in belogic and GBATEK)
pub const reg_tm3cnt_l: *volatile u16 = @ptrFromInt(io_address + 0x010c);

/// REG_TM3CNT_H (Alternate name for REG_TM3CNT in belogic and GBATEK)
pub const reg_tm3cnt_h: *volatile u16 = @ptrFromInt(io_address + 0x010e);

/// REG_KEYS (Alternate name for REG_KEYINPUT in belogic and GBATEK)
pub const reg_keys: *volatile u16 = @ptrFromInt(io_address + 0x0130);

/// REG_P1 (Alternate name for REG_KEYINPUT in belogic and GBATEK)
pub const reg_p1: *volatile u16 = @ptrFromInt(io_address + 0x0130);

/// REG_P1CNT (Alternate name for REG_KEYCNT in belogic and GBATEK)
pub const reg_p1cnt: *volatile u16 = @ptrFromInt(io_address + 0x0132);

/// REG_SCD0 (Alternate name for REG_SIOMULTI0 in belogic and GBATEK)
pub const reg_scd0: *volatile u16 = @ptrFromInt(io_address + 0x0120);

/// REG_SCD1 (Alternate name for REG_SIOMULTI1 in belogic and GBATEK)
pub const reg_scd1: *volatile u16 = @ptrFromInt(io_address + 0x0122);

/// REG_SCD2 (Alternate name for REG_SIOMULTI2 in belogic and GBATEK)
pub const reg_scd2: *volatile u16 = @ptrFromInt(io_address + 0x0124);

/// REG_SCD3 (Alternate name for REG_SIOMULTI3 in belogic and GBATEK)
pub const reg_scd3: *volatile u16 = @ptrFromInt(io_address + 0x0126);

/// REG_SCCNT (belogic/GBATEK)
pub const reg_sccnt: *volatile u32 = @ptrFromInt(io_address + 0x0128);

/// REG_SCCNT_L (Alternate name for REG_SIOCNT in belogic and GBATEK)
pub const reg_sccnt_l: *volatile u16 = @ptrFromInt(io_address + 0x0128);

/// REG_SCCNT_H (Alternate name for REG_SIODATA8 in belogic and GBATEK)
pub const reg_sccnt_h: *volatile u16 = @ptrFromInt(io_address + 0x012a);

/// REG_R (Alternate name for REG_RCNT in belogic and GBATEK)
pub const reg_r: *volatile u16 = @ptrFromInt(io_address + 0x0134);

/// REG_HS_CTRL (Alternate name for REG_JOYCNT in belogic and GBATEK)
pub const reg_hs_ctrl: *volatile u16 = @ptrFromInt(io_address + 0x0140);

/// REG_JOYRE (Alternate name for REG_JOY_RECV in belogic and GBATEK)
pub const reg_joyre: *volatile u32 = @ptrFromInt(io_address + 0x0150);

/// REG_JOYRE_L (belogic/GBATEK)
pub const reg_joyre_l: *volatile u16 = @ptrFromInt(io_address + 0x0150);

/// REG_JOYRE_H (belogic/GBATEK)
pub const reg_joyre_h: *volatile u16 = @ptrFromInt(io_address + 0x0152);

/// REG_JOYTR (Alternate name for REG_JOY_TRANS in belogic and GBATEK)
pub const reg_joytr: *volatile u32 = @ptrFromInt(io_address + 0x0154);

/// REG_JOYTR_L (belogic/GBATEK)
pub const reg_joytr_l: *volatile u16 = @ptrFromInt(io_address + 0x0154);

/// REG_JOYTR_H (belogic/GBATEK)
pub const reg_joytr_h: *volatile u16 = @ptrFromInt(io_address + 0x0156);

/// REG_JSTAT (Alternate name for REG_JOYSTAT in belogic and GBATEK)
pub const reg_jstat: *volatile u16 = @ptrFromInt(io_address + 0x0158);

/// REG_WSCNT (Alternate name for REG_WAITCNT in belogic and GBATEK)
pub const reg_wscnt: *volatile u16 = @ptrFromInt(io_address + 0x0204);
