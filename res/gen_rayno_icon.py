"""Generate the RAYNODesk 'RD' icons from the brand colour.

Keeps the same size sets as the icons it replaces:
  res/icon.ico       16, 32, 48, 64, 128
  res/tray-icon.ico  32
The tray icon is drawn on transparent background so it inherits the taskbar theme.
"""
import os

from PIL import Image, ImageDraw, ImageFont

BRAND = (0x39, 0xB7, 0xFF)
WHITE = (0xFF, 0xFF, 0xFF)
RES = os.path.dirname(os.path.abspath(__file__))


def _font(size):
    # Prefer a bold UI face; Arial ships with Windows.
    for name in ('segoeuib.ttf', 'arialbd.ttf', 'arial.ttf'):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_rd(size, background=None):
    """Draw 'RD' centred. Returns an RGBA image."""
    ss = 8  # supersample, then downscale for clean edges
    big = size * ss
    img = Image.new('RGBA', (big, big), background or (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    if background:
        # Rounded square plate so the mark reads at 16px.
        radius = int(big * 0.18)
        draw.rounded_rectangle([0, 0, big - 1, big - 1], radius=radius, fill=background)

    font = _font(int(big * 0.62))
    text = 'RD'
    # Centre on the text's own ink box rather than the font metrics.
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (big - w) // 2 - box[0]
    y = (big - h) // 2 - box[1]
    draw.text((x, y), text, font=font, fill=WHITE)

    return img.resize((size, size), Image.LANCZOS)


def main():
    app_sizes = [16, 32, 48, 64, 128]
    frames = [draw_rd(s, background=BRAND + (255,)) for s in app_sizes]
    ico = os.path.join(RES, 'icon.ico')
    frames[-1].save(ico, format='ICO', sizes=[(s, s) for s in app_sizes])
    print('wrote', ico, app_sizes)

    tray_sizes = [32]
    tray = draw_rd(32).save(os.path.join(RES, 'tray-icon.ico'), format='ICO',
                            sizes=[(32, 32)])
    print('wrote tray-icon.ico', tray_sizes)


if __name__ == '__main__':
    main()