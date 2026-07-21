from PIL import Image
import numpy as np

for breed in ['orange', 'british', 'siamese']:
    path = f'assets/art/delivery/portraits/portrait_{breed}.png'
    img = Image.open(path).convert('RGBA')
    arr = np.array(img)
    
    # 背景色 = 四角颜色均值
    corners = [arr[0,0], arr[0,-1], arr[-1,0], arr[-1,-1]]
    bg = tuple(int(c) for c in np.mean(corners, axis=0)[:3])
    tolerance = 40
    
    r = arr[:,:,0].astype(int)
    g = arr[:,:,1].astype(int)
    b = arr[:,:,2].astype(int)
    mask = (abs(r - bg[0]) < tolerance) & (abs(g - bg[1]) < tolerance) & (abs(b - bg[2]) < tolerance)
    arr[:,:,3] = np.where(mask, 0, 255)
    
    result = Image.fromarray(arr, 'RGBA')
    result.save(path)
    print(f'{breed}: transparent bg={bg}, {mask.sum()} pixels cleared')
