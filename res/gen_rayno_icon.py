"""Generate the RAYNODesk icon set from res/rayno-logo.png.

The master logo is used at full size by nothing; it is only the source. This
script resizes it down to every size the build embeds, keeping the same size
sets as the icons they replace:
  res/icon.ico        16, 32, 48, 64, 128  (exe resource, shortcuts)
  res/tray-icon.ico   32                    (taskbar tray)
  res/rayno-icon.png  128                   (Sciter header / window icon)
Replace res/rayno-logo.png and re-run this to rebrand.
"""
import os

from PIL import Image

RES = os.path.dirname(os.path.abspath(__file__))
MASTER = os.path.join(RES, 'rayno-logo.png')

ICO_SIZES = [16, 32, 48, 64, 128]
UI_SIZE = 128


def main():
    master = Image.open(MASTER)
    if master.mode != 'RGBA':
        master = master.convert('RGBA')

    frames = [master.resize((s, s), Image.LANCZOS) for s in ICO_SIZES]
    ico = os.path.join(RES, 'icon.ico')
    frames[-1].save(ico, format='ICO', sizes=[(s, s) for s in ICO_SIZES])
    print('wrote', ico, ICO_SIZES)

    tray = os.path.join(RES, 'tray-icon.ico')
    master.resize((32, 32), Image.LANCZOS).save(tray, format='ICO',
                                                sizes=[(32, 32)])
    print('wrote', tray, [32])

    # The UI draws this at 16px, and get_icon() base64-embeds it, so keep it small.
    ui = os.path.join(RES, 'rayno-icon.png')
    master.resize((UI_SIZE, UI_SIZE), Image.LANCZOS).save(ui, format='PNG',
                                                          optimize=True)
    print('wrote', ui, [UI_SIZE])


if __name__ == '__main__':
    main()
