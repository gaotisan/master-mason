import sys, os, cv2, numpy as np
v, out, a, b = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
os.makedirs(out, exist_ok=True)
cap = cv2.VideoCapture(v)
i = 0
while True:
    ok, f = cap.read()
    if not ok: break
    i += 1
    if a <= i <= b:
        s = cv2.resize(f, (640, 360), interpolation=cv2.INTER_AREA)
        cv2.imwrite(os.path.join(out, 'f_%04d.png' % i), s)
print(i)
