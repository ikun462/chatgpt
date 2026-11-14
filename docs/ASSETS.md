# 数据、素材与许可

所有纹理随项目分发，运行时不联网。下列下载在本次开发中实际取得并转换；没有使用 Universe Sandbox 的代码、素材或资源。

| 项目文件 | 来源与处理 |
| --- | --- |
| `earth_day.jpg` | NASA Earth Observatory, Blue Marble Next Generation, January 2004；原始 21600×10800 JPEG 下采样至 4096×2048。NASA 的真实卫星数据合成，并非实时影像。 |
| `earth_clouds.png` | NASA SVS 4439 公开的 NOAA Climate Prediction Center 云层序列，第 01000 帧；2048×1024 TIFF 转灰度 PNG。独立球壳贴图，仅作视觉漂移。 |
| `earth_night.jpg` | NASA Earth Observatory 2012 Earth at Night, 3600×1800；亮度阈值提取夜间发光区域，暖色由材质赋予，不是精确灯光辐射模型。 |
| `moon.jpg` | NASA SVS 4720, CGI Moon Kit, LRO/LROC color map；4096×2048 TIFF 转 JPEG。 |
| `NotoSansSC.otf` | Noto Sans CJK Regular 字体集合中简体中文子字体；保留常用汉字、ASCII 和 UI 符号。SIL Open Font License 1.1，详见 `licenses/Noto-CJK.txt`。 |

## 可核查的原始下载与说明页

地表：
- https://science.nasa.gov/earth/earth-observatory/blue-marble-next-generation/base-map/
- https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/january/world.200401.3x21600x10800.jpg
- Credit: NASA Earth Observatory / Blue Marble Next Generation，Reto Stöckli 等团队；MODIS 数据。

云图：
- https://svs.gsfc.nasa.gov/4439/
- https://svs.gsfc.nasa.gov/vis/a000000/a004400/a004439/frames/2048x1024_1x1_30p/clouds_cpc/flat_cpc_clouds_2048x1024.01000.tif
- Credit: NOAA Climate Prediction Center；NASA Scientific Visualization Studio 分发。模型没有把该静态云图声称为实时天气。

夜光：
- https://science.nasa.gov/earth/earth-observatory/earth-at-night/
- https://assets.science.nasa.gov/content/dam/science/esd/eo/images/imagerecords/79000/79765/dnb_land_ocean_ice.2012.3600x1800.jpg
- Credit: NASA Earth Observatory / NOAA NGDC / Suomi NPP VIIRS。亮区域可能包含城市以外的光源。

月面：
- https://svs.gsfc.nasa.gov/4720/
- https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_poles_4k.tif
- Credit: NASA/Goddard Space Flight Center Scientific Visualization Studio；LRO/LROC。

NASA 媒体使用指引：https://www.nasa.gov/nasa-brand-center/images-and-media/
NASA SVS 使用说明：https://svs.gsfc.nasa.gov/help/
NASA/NOAA 标识没有用作软件品牌；软件不暗示 NASA 或 NOAA 赞助。第三方权利如有独立标注仍适用。

## 物理常数和初始条件

NASA NSSDCA Moon Fact Sheet：
https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html

NASA Earth Fact Sheet：
https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html

| 参数 | 本项目使用值 |
| --- | --- |
| 地球质量 | 5.9724 × 10²⁴ kg |
| 月球质量 | 7.346 × 10²² kg |
| 地球体积平均半径 | 6371.0 km |
| 月球体积平均半径 | 1737.4 km |
| 相对轨道半长轴 | 384400 km |
| 相对轨道偏心率 | 0.0549 |
| 相对黄道倾角 | 5.145° |
| 地球自转周期 | 86164.1 s，取公开恒星日的近似值 |
| 月球自转周期 | 655.720 h |
| 地轴倾角（视觉） | 23.44° |
| 引力常数 G | 6.67430 × 10⁻¹¹ m³·kg⁻¹·s⁻²，CODATA/NIST |

G 来源：https://physics.nist.gov/cgi-bin/cuu/Value?bg

密度由质量和球形体积计算，而不是另行硬编码不一致的密度。近地点距离 a(1−e)，相对速度由 vis-viva 公式 sqrt(G(M+m)(1+e)/(a(1−e))) 计算，然后分配到质量加权的质心位置／速度。升交点和近地点方向被人为选为坐标轴；初始自转经度、恒定太阳方向、云层漂移速度是显示设置，不冒充实测星历。

## 资源完整性

`assets-manifest.json` 记录分发文件 SHA-256 和原始来源 SHA-256。执行：

```
python tools/verify_assets.py
```

原始工程代码 MIT；Godot 和 godot-cpp 的 MIT 声明及 Godot 第三方许可清单位于 `docs/licenses/`，分发的便携版也带同一组声明。
