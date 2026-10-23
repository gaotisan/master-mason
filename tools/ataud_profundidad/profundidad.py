import sys, numpy as np, onnxruntime as ort
from PIL import Image
modelo, entrada, salida = sys.argv[1:4]
img = Image.open(entrada).convert("RGB")
W, H = img.size
h, w = 518, 924
x = np.asarray(img.resize((w, h), Image.BICUBIC), dtype=np.float32) / 255.0
x = (x - [0.485, 0.456, 0.406]) / [0.229, 0.224, 0.225]
x = x.transpose(2, 0, 1)[None].astype(np.float32)
s = ort.InferenceSession(modelo, providers=["CPUExecutionProvider"])
i = s.get_inputs()[0]
print(i.name, i.type, i.shape)
if "float16" in i.type: x = x.astype(np.float16)
d = s.run(None, {i.name: x})[0].astype(np.float32).squeeze()
print(d.shape, d.min(), d.max())
d = (d - d.min()) / (d.max() - d.min())
Image.fromarray((d * 65535).astype(np.uint16)).resize((W, H), Image.BICUBIC).save(salida)
Image.fromarray((d * 255).astype(np.uint8)).resize((W // 2, H // 2), Image.BICUBIC).save(salida.replace(".png", "_ver.png"))
