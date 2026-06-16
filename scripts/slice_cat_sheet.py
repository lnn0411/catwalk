#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import os
import sys
from PIL import Image

def slice_and_clean_sheet(sheet_path, output_dir, num_frames=10, target_size=(100, 140)):
    if not os.path.exists(sheet_path):
        print(f"Error: Sheet file not found at {sheet_path}")
        return False
        
    os.makedirs(output_dir, exist_ok=True)
    
    # 1. 打开雪碧图并转换为 RGBA
    sheet = Image.open(sheet_path).convert("RGBA")
    sheet_w, sheet_h = sheet.size
    
    frame_w = sheet_w // num_frames
    print(f"Loaded sheet: {sheet_w}x{sheet_h}, splitting into {num_frames} frames of {frame_w}x{sheet_h}")
    
    for i in range(num_frames):
        # 2. 裁剪单帧
        left = i * frame_w
        right = left + frame_w
        frame = sheet.crop((left, 0, right, sheet_h))
        
        # 3. 动态去色背景 (Chroma-keying for white/light-gray background)
        # 自动将极亮/极低饱和度的底纸色转为 100% 透明通道
        frame = frame.convert("RGBA")
        fw, fh = frame.size
        for x in range(fw):
            for y in range(fh):
                r, g, b, a = frame.getpixel((x, y))
                # 背景色识别阈值 (亮度高且极度接近灰色/米黄)
                if r > 220 and g > 220 and b > 210 and abs(r-g) < 15 and abs(g-b) < 15:
                    frame.putpixel((x, y), (0, 0, 0, 0))
                    
        # 4. 等比缩放并填充至标准的 100x140 容器中 (防止变形)
        aspect = float(fw) / float(fh)
        target_w = int(target_size[1] * aspect)
        target_h = target_size[1]
        
        # 如果缩放后宽过大，按宽限制
        if target_w > target_size[0]:
            target_w = target_size[0]
            target_h = int(target_size[0] / aspect)
            
        resized_frame = frame.resize((target_w, target_h), Image.Resampling.LANCZOS)
        
        # 5. 创建 100x140 的透明画布，并将猫咪脚底对齐到 Y=135
        container = Image.new("RGBA", target_size, (0, 0, 0, 0))
        paste_x = (target_size[0] - target_w) // 2
        paste_y = target_size[1] - target_h - 5  # 底部留 5px 安全余量，使脚底落在 Y=135
        
        container.alpha_composite(resized_frame, (paste_x, paste_y))
        
        # 6. 保存单帧
        out_name = f"idle_{i:02d}.png"
        out_path = os.path.join(output_dir, out_name)
        container.save(out_path, "PNG")
        print(f"  ✓ Saved: {out_path}")
        
    print(f"Successfully sliced {num_frames} frames into {output_dir}")
    return True

if __name__ == "__main__":
    # 默认路径
    default_sheet = "/home/agentuser/catwalk/assets/art/cats/orange_tabby/idle_sheet.png"
    default_out = "/home/agentuser/catwalk/assets/art/cats/orange_tabby"
    
    if len(sys.argv) > 1:
        default_sheet = sys.argv[1]
    if len(sys.argv) > 2:
        default_out = sys.argv[2]
        
    slice_and_clean_sheet(default_sheet, default_out)
