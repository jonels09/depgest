import sys
path = r'c:\Users\ACER\Documents\flutter project\depgest\backend_python\models\prophet_forecaster.py'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("base_amount = 1000.0", "base_amount = 0.0")

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Prophet patched successfully")
