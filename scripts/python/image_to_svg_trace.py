"""
图片转 SVG 矢量化描摹工具
将菠萝的照片转换为矢量 SVG 轮廓
"""
from PIL import Image, ImageFilter, ImageOps

def trace_image_to_svg(img_path, output_path, threshold=30):
    """将图片描摹为 SVG 矢量轮廓"""
    
    img = Image.open(img_path)
    # 缩小到合理尺寸
    max_size = 400
    ratio = max_size / max(img.size)
    new_size = (int(img.size[0] * ratio), int(img.size[1] * ratio))
    img = img.resize(new_size, Image.LANCZOS)
    
    # 转为灰度
    gray = img.convert('L')
    
    # 边缘检测
    edges = gray.filter(ImageFilter.FIND_EDGES)
    edges = edges.filter(ImageFilter.SMOOTH)
    
    # 二值化
    bw = edges.point(lambda x: 255 if x > threshold else 0)
    bw = ImageOps.invert(bw)
    
    # 获取像素数据
    pixels = bw.load()
    w, h = bw.size
    
    # 寻找轮廓点
    contours = []
    visited = set()
    
    def find_next_point(x, y):
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                if dx == 0 and dy == 0:
                    continue
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h:
                    if pixels[nx, ny] > 128 and (nx, ny) not in visited:
                        return nx, ny
        return None
    
    # 采集轮廓
    for y in range(0, h, 1):
        for x in range(0, w, 1):
            if pixels[x, y] > 128 and (x, y) not in visited:
                contour = []
                cx, cy = x, y
                while (cx, cy) is not None and len(contour) < 5000:
                    visited.add((cx, cy))
                    contour.append((cx, cy))
                    cx, cy = find_next_point(cx, cy)
                if len(contour) > 20:
                    contours.append(contour)
    
    # 生成 SVG
    scale = 600 / max(w, h)
    offset_x = (600 - w * scale) / 2
    offset_y = (600 - h * scale) / 2
    
    svg_parts = []
    svg_parts.append('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 600" width="600" height="600">')
    svg_parts.append('<rect width="600" height="600" fill="#F5F0E6"/>')
    
    for contour in contours:
        if len(contour) < 3:
            continue
        
        simplified = contour[::2]
        
        path_data = []
        for i, (px, py) in enumerate(simplified):
            sx = px * scale + offset_x
            sy = py * scale + offset_y
            if i == 0:
                path_data.append(f'M {sx:.1f} {sy:.1f}')
            else:
                path_data.append(f'L {sx:.1f} {sy:.1f}')
        
        if path_data:
            path_data.append('Z')
            svg_parts.append(
                f'<path d="{" ".join(path_data)}" '
                f'fill="none" stroke="#4A3A2A" stroke-width="1.5" '
                f'stroke-linecap="round" stroke-linejoin="round"/>'
            )
    
    svg_parts.append('</svg>')
    
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write('\n'.join(svg_parts))
    
    print(f'SVG 已生成: {output_path}')
    print(f'轮廓数: {len(contours)}')
    print(f'图片尺寸: {w}x{h}')

if __name__ == '__main__':
    img_path = r'D:\Reasonix_Workspace\微信图片_20260717150742_353_151.jpg'
    output_path = r'D:\Reasonix_Workspace\菠萝猫_trace.svg'
    trace_image_to_svg(img_path, output_path, threshold=20)
