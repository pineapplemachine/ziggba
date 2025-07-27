import math
import struct
from PIL import Image

"""
This script encodes font image data into a packed binary format suitable
for embedding with ziggba.
"""

def __main__():
    pack_font("font_latin.png", "font_latin.bin", (8, 12), (0, 24, 128, 72))
    pack_font("font_latin.png", "font_latin_supplement.bin", (8, 12), (0, 120, 128, 72))
    pack_font("font_kana.png", "font_kana.bin", (12, 12), (0, 0, 160, 176))

def pack_font(path_in, path_out, ch_size, im_rect):
    print("Reading image:", repr(path_in))
    im = Image.open(path_in)
    im_pixels = im.load()
    im_rect_x, im_rect_y, im_rect_size_x, im_rect_size_y = im_rect
    ch_size_x, ch_size_y = ch_size
    ch_count_x = math.floor(im_rect_size_x / ch_size_x)
    ch_count_y = math.floor(im_rect_size_y / ch_size_y)
    ch_list = []
    for ch_y in range(ch_count_y):
        for ch_x in range(ch_count_x):
            ch_list.append(Char(im_pixels, (
                im_rect_x + (ch_x * ch_size_x),
                im_rect_y + (ch_y * ch_size_y),
                ch_size_x,
                ch_size_y,
            )))
    ch_headers = bytes()
    ch_rows = bytes()
    ch_headers_len = 4 * len(ch_list)
    for ch in ch_list:
        ch_offset = 0
        if not ch.is_blank():
            ch_offset = len(ch_rows) + ch_headers_len
            ch_rows += ch.encode_rows()
        ch_headers += ch.encode_header()
        ch_headers += bytes([
            (ch_offset & 0xff),
            (ch_offset >> 8),
        ])
    assert(len(ch_headers) == ch_headers_len)
    print("Writing output (%db headers, %db bitmap, %db total): %s" % (
        len(ch_headers),
        len(ch_rows),
        len(ch_headers) + len(ch_rows),
        repr(path_out)
    ))
    with open(path_out, "wb") as f:
        f.write(ch_headers)
        f.write(ch_rows)

class Char:
    def __init__(self, im_pixels, im_rect):
        self.im_rect_x = im_rect[0]
        self.im_rect_y = im_rect[1]
        self.im_rect_x_size = im_rect[2]
        self.im_rect_y_size = im_rect[3]
        self.im_rect_x_max = self.im_rect_x + self.im_rect_x_size
        self.im_rect_y_max = self.im_rect_y + self.im_rect_y_size
        self.x_min = self.im_rect_x_max
        self.x_max = self.im_rect_x
        self.y_min = self.im_rect_y_max
        self.y_max = self.im_rect_y
        self.y_min_first = self.im_rect_y_max
        self.y_max_first = self.im_rect_y
        self.y_min_last = self.im_rect_y_max
        self.y_max_last = self.im_rect_y
        self.rows = []
        for px_x in range(self.im_rect_x, self.im_rect_x_max):
            for px_y in range(self.im_rect_y, self.im_rect_y_max):
                if im_pixels[px_x, px_y]:
                    self.x_min = min(self.x_min, px_x)
                    self.x_max = max(self.x_max, px_x + 1)
                    self.y_min = min(self.y_min, px_y)
                    self.y_max = max(self.y_max, px_y + 1)
        if self.x_min >= self.x_max:
            return
        for px_y in range(self.im_rect_y, self.im_rect_y_max):
            if im_pixels[self.x_min, px_y]:
                self.y_min_first = min(self.y_min_first, px_y)
                self.y_max_first = max(self.y_max_first, px_y + 1)
        for px_y in range(self.im_rect_y, self.im_rect_y_max):
            if im_pixels[self.x_max - 1, px_y]:
                self.y_min_last = min(self.y_min_last, px_y)
                self.y_max_last = max(self.y_max_last, px_y + 1)
        if self.x_max - self.x_min > 12 or self.y_max - self.y_min > 12:
            raise ValueError(
                "Maximum allowed character size is 12x12 pixels. " +
                f"Found {self.x_max - self.x_min}x{self.y_max - self.y_min}."
            )
        assert(0 <= self.x_max - self.x_min < 16)
        assert(0 <= self.y_max - self.y_min < 16)
        assert(0 <= self.y_min_first - self.y_min < 16)
        assert(0 <= self.y_max_first - self.y_min < 16)
        assert(0 <= self.y_min_last - self.y_min < 16)
        assert(0 <= self.y_max_last - self.y_min < 16)
        assert(0 <= self.y_min - self.im_rect_y < 16)
        for px_y in range(self.y_min, self.y_max):
            row = 0
            i = 0
            for px_x in range(self.x_min, self.x_max):
                if im_pixels[px_x, px_y]:
                    row |= (1 << i)
                i += 1
            self.rows.append(row)
    
    def is_blank(self):
        return self.x_max <= self.x_min or self.y_max <= self.y_min
    
    def encode_header(self):
        b = []
        b.append(
            max(0, self.x_max - self.x_min) |
            (max(0, self.y_max - self.y_min) << 4)
        )
        b.append(
            max(0, self.y_min - self.im_rect_y) |
            # Kerning flag intended to match 'f' and 'r'
            ((
                self.y_min_last - self.im_rect_y <= 5 and
                self.y_min_last == self.y_max_last - 1
            ) << 4) |
            # Flag for chars that should have a reduced gap with the above
            ((
                self.y_min_first - self.im_rect_y > 5
            ) << 5) |
            # Kerning flag intended to match 'j'
            ((
                self.y_min_first - self.im_rect_y >= 9 and
                self.y_min_first == self.y_max_first - 1
            ) << 6) |
            # Flag for chars that should have a reduced gap with the above
            ((
                self.y_max_last - self.im_rect_y < 9
            ) << 7)
        )
        return bytes(b)
    
    def encode_rows(self):
        wide = (self.x_max - self.x_min) > 8
        if wide:
            return struct.pack("<" + "H" * len(self.rows), *self.rows)
        else:
            return struct.pack("<" + "B" * len(self.rows), *self.rows)

if __name__ == "__main__":
    __main__()
