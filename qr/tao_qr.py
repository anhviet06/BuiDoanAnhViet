# -*- coding: utf-8 -*-
"""
Script MỘT LẦN: tạo ảnh PNG mã QR cho 5 ca cố định của TimeGuard.
  python D:\\Buidoananhviet\\qr\\tao_qr.py            -> tạo 6 ảnh trong thư mục này
  python D:\\Buidoananhviet\\qr\\tao_qr.py --verify   -> giải mã lại từng ảnh (OpenCV) và đối chiếu token trong DB

Nội dung QR = ĐÚNG qrToken (không tiền tố, không JSON). Token cố định, khớp với backend
(Models/ShiftTime.cs -> FixedShifts). Nếu admin bấm "Đổi mã QR" thì ảnh cũ lỗi thời: sửa token dưới đây rồi chạy lại.
Yêu cầu: pip install qrcode pillow opencv-python (chỉ để chạy script này, không thuộc backend/app).
"""
import os
import subprocess
import sys

import qrcode
from PIL import Image, ImageDraw, ImageFont

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

HERE = os.path.dirname(os.path.abspath(__file__))

# (tên ca, giờ hiển thị, qrToken, tên file)
SHIFTS = [
    ("Ca 1", "06:00 - 12:00", "TG-CA1-KJJ446CX", "QR_Ca1.png"),
    ("Ca 2", "12:00 - 18:00", "TG-CA2-E7U48ZW8", "QR_Ca2.png"),
    ("Ca 3", "18:00 - 24:00", "TG-CA3-TV5FDGX8", "QR_Ca3.png"),
    ("Ca gãy sáng", "05:00 - 09:00", "TG-GAYS-ZGT7Q99U", "QR_Ca_gay_sang.png"),
    ("Ca gãy chiều", "16:00 - 20:00", "TG-GAYC-JSRSED2A", "QR_Ca_gay_chieu.png"),
]
SUMMARY = "QR_tong_hop.png"
QUIET = 4  # vùng yên tĩnh (số mô-đun)

FONT_REG = r"C:\Windows\Fonts\arial.ttf"
FONT_BOLD = r"C:\Windows\Fonts\arialbd.ttf"
FONT_MONO = r"C:\Windows\Fonts\consolab.ttf"


def font(path, size):
    return ImageFont.truetype(path, size)


def qr_image(token, target_px):
    """QR nền trắng, mô-đun VUÔNG, sửa lỗi Q, vùng yên tĩnh >= 4 mô-đun, kích thước nguyên bội của mô-đun."""
    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_Q, border=QUIET, box_size=1)
    qr.add_data(token)
    qr.make(fit=True)
    matrix = qr.get_matrix()  # đã gồm viền yên tĩnh
    n = len(matrix)
    box = max(1, target_px // n)
    img = Image.new("RGB", (n * box, n * box), "white")
    d = ImageDraw.Draw(img)
    for y, row in enumerate(matrix):
        for x, on in enumerate(row):
            if on:
                d.rectangle([x * box, y * box, (x + 1) * box - 1, (y + 1) * box - 1], fill=(0, 0, 0))
    return img


def centered(d, text, y, fnt, width, fill=(0, 0, 0)):
    w = d.textlength(text, font=fnt)
    d.text(((width - w) / 2, y), text, font=fnt, fill=fill)


def make_single(name, hours, token, filename):
    W, H = 1400, 1750
    img = Image.new("RGB", (W, H), "white")
    q = qr_image(token, 1100)
    img.paste(q, ((W - q.width) // 2, 40))
    d = ImageDraw.Draw(img)
    y = 40 + q.height + 20
    centered(d, f"{name} \u00b7 {hours}", y, font(FONT_BOLD, 84), W)
    centered(d, "Mã gõ tay (nhập đúng từng ký tự):", y + 125, font(FONT_REG, 48), W, (80, 80, 80))
    centered(d, token, y + 195, font(FONT_MONO, 88), W)
    centered(d, "TimeGuard \u00b7 Quét mã để chấm công", H - 80, font(FONT_REG, 40), W, (120, 120, 120))
    img.save(os.path.join(HERE, filename), "PNG")
    return img.size


def make_summary():
    # Khổ A4 dọc 300 dpi, 2 cột x 3 hàng (5 mã + 1 ô hướng dẫn)
    W, H = 2480, 3508
    img = Image.new("RGB", (W, H), "white")
    d = ImageDraw.Draw(img)
    centered(d, "TimeGuard \u00b7 Mã QR chấm công theo ca", 70, font(FONT_BOLD, 96), W)
    cell_w, cell_h = W // 2, 1080
    top = 230
    for i, (name, hours, token, _) in enumerate(SHIFTS):
        col, row = i % 2, i // 2
        ox, oy = col * cell_w, top + row * cell_h
        q = qr_image(token, 760)
        img.paste(q, (ox + (cell_w - q.width) // 2, oy))
        cy = oy + q.height + 10
        centered_x = lambda text, y, fnt, fill=(0, 0, 0): d.text((ox + (cell_w - d.textlength(text, font=fnt)) / 2, y), text, font=fnt, fill=fill)
        centered_x(f"{name} \u00b7 {hours}", cy, font(FONT_BOLD, 64))
        centered_x(token, cy + 90, font(FONT_MONO, 60))
        d.rectangle([ox + 40, oy - 10, ox + cell_w - 40, oy + cell_h - 40], outline=(200, 200, 200), width=3)
    # ô thứ 6: hướng dẫn
    ox, oy = cell_w, top + 2 * cell_h
    lines = ["Cách dùng", "1. Mở app TimeGuard -> Chấm công.", "2. Quét mã của ĐÚNG ca đang làm", "    (hoặc nhập mã gõ tay bên dưới mã).", "3. Cho phép vị trí, làm thử thách khuôn mặt.", "", "Ca chồng giờ là chủ ý: mã QR quyết", "định ca. Chưa check-out ca này thì", "không chấm được ca khác."]
    for k, line in enumerate(lines):
        d.text((ox + 90, oy + 80 + k * 80), line, font=font(FONT_BOLD if k == 0 else FONT_REG, 58 if k == 0 else 46), fill=(0, 0, 0))
    d.rectangle([ox + 40, oy - 10, ox + cell_w - 40, oy + cell_h - 40], outline=(200, 200, 200), width=3)
    img.save(os.path.join(HERE, SUMMARY), "PNG")
    return img.size


def db_tokens():
    out = subprocess.run(
        ["sqlcmd", "-S", r"(localdb)\MSSQLLocalDB", "-d", "Buidoananhviet", "-E", "-h", "-1", "-W", "-f", "65001",
         "-Q", "SET NOCOUNT ON; select CONCAT(Name, '|', QrToken) from Shifts"],
        capture_output=True, text=True, encoding="utf-8", errors="replace").stdout
    res = {}
    for line in out.splitlines():
        if "|" in line:
            n, t = line.rsplit("|", 1)
            res[t.strip()] = n.strip()
    return res


def verify():
    import cv2
    import numpy as np
    db = db_tokens()
    ok = True
    files = [(f, t) for _, _, t, f in SHIFTS]
    for fname, token in files:
        img = cv2.imread(os.path.join(HERE, fname))
        det = cv2.QRCodeDetector()
        data, _, _ = det.detectAndDecode(img)
        if not data:  # thử thu nhỏ
            small = cv2.resize(img, None, fx=0.5, fy=0.5, interpolation=cv2.INTER_AREA)
            data, _, _ = det.detectAndDecode(small)
        good = data == token and token in db
        ok &= good
        print(f"{'OK ' if good else 'LỖI'} {fname}: giải mã='{data}' | khớp DB={'có (' + db.get(token, '?') + ')' if token in db else 'KHÔNG'}")
    # tờ tổng hợp: giải mã nhiều mã
    img = cv2.imread(os.path.join(HERE, SUMMARY))
    det = cv2.QRCodeDetector()
    try:
        ret, infos, _, _ = det.detectAndDecodeMulti(img)
        found = sorted(i for i in infos if i)
    except Exception:
        found = []
    want = sorted(t for _, _, t, _ in SHIFTS)
    if found != want:
        # dự phòng: cắt từng ô và giải mã riêng
        found = []
        cell_w, cell_h, top = img.shape[1] // 2, 1080, 230
        for i in range(5):
            c, r = i % 2, i // 2
            crop = img[top + r * cell_h: top + (r + 1) * cell_h - 120, c * cell_w:(c + 1) * cell_w]
            data, _, _ = cv2.QRCodeDetector().detectAndDecode(crop)
            found.append(data)
        found.sort()
    good = found == want
    ok &= good
    print(f"{'OK ' if good else 'LỖI'} {SUMMARY}: giải mã {len([f for f in found if f])}/5 mã, khớp danh sách token={good}")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    if "--verify" in sys.argv:
        verify()
    for name, hours, token, fname in SHIFTS:
        w, h = make_single(name, hours, token, fname)
        print(f"Đã tạo {fname} ({w}x{h}) <- {token}")
    w, h = make_summary()
    print(f"Đã tạo {SUMMARY} ({w}x{h})")
