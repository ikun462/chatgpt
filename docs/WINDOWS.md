# Windows 安装、构建和运行

## 版本和渲染选择

固定 **Godot 4.4.1 stable 标准版（非 .NET，Windows x86_64）** 和 `godot-cpp` 的 `godot-4.4.1-stable` 标签，绑定提交 `e4b7c25e721ce3435a029087e3917a30aa73f06b`。选择这个已发布版本是为了可复现，并不是声称它是 2026 年最新 Godot。不要混用 4.3 的引擎、4.5 的绑定或不同版本导出模板。

RX 5700 XT 支持 Vulkan，可运行 Forward+，不需要 RTX 或硬件光追。默认 1080p 逻辑画布、1440×810 初始窗口、标准档 2× MSAA、4K 地表／月面，桌面可最大化至 1920×1080。16GB 内存无需额外提高到 32GB。只有两个实体和三层地球球面，不启用昂贵的体积云／实时 GI／光追。

低档关闭云层、云阴影、MSAA 和辉光；标准档为 2× MSAA；高档为 4× MSAA。三档均保留 4K 纹理，暂不提供纹理内存分档。OpenGL 兼容模式是启动故障的后备路径，不具备 Forward+ 的 Bloom。

## 便携版本

完整解压 Windows ZIP，运行 `启动模拟器.bat`。旁边必须存在：

```
SolarSandbox.exe
SolarSandbox.pck
solar_physics.dll
```

便携包包含 Godot 官方发布运行时和本项目交叉编译的 DLL，不需要 Python、CMake 或编辑器。兼容模式启动脚本会保留控制台输出，发生问题可复制错误文本。开发版未做代码签名。实际 Windows 启动和 RX 5700 XT 帧率仍需实机验收，不能从 Linux 软件渲染测试推断。

## 源码构建环境

安装下列工具，完成后打开新的 PowerShell：

1. [Godot 4.4.1 下载归档](https://godotengine.org/download/archive/4.4.1-stable/)：解压标准版。
2. [Visual Studio 2022 Build Tools](https://visualstudio.microsoft.com/downloads/)：勾选“使用 C++ 的桌面开发”，包含 MSVC v143、Windows 10/11 SDK、CMake 工具。
3. [Python 3.12](https://www.python.org/downloads/windows/)：勾选加入 PATH。
4. [Git for Windows](https://git-scm.com/download/win)。完整源代码包已包含绑定，但脚本也能下载锁定版本。
5. 如果系统 PATH 没有 CMake，可执行 `python -m pip install cmake`，随后重新打开 PowerShell。

检查：

```powershell
python --version
git --version
cmake --version
```

假设源码解压到 `D:\SolarSandboxSource`，Godot 在 `D:\Tools\Godot`。以下命令中的路径按实际解压位置替换，优先选择带 `_console.exe` 的 Godot 可执行文件：

```powershell
cd D:\SolarSandboxSource
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_windows.ps1 `
  -GodotPath "D:\Tools\Godot\Godot_v4.4.1-stable_win64_console.exe"
```

脚本依次验证绑定、编译 C++、运行核心 CTest、导入 Godot 资源、运行扩展及界面集成测试。`ExecutionPolicy Bypass` 只用于这个进程，不永久修改系统策略。

之后运行：

```powershell
& "D:\Tools\Godot\Godot_v4.4.1-stable_win64_console.exe" --path .\godot
```

或者在 Godot 导入 `godot/project.godot` 后按 F6/F5。不要直接用 Godot 的 RigidBody3D 替换天体物理。

## 导出独立 EXE

在 Godot 编辑器的“编辑器 → 管理导出模板”中安装 **4.4.1 stable** 模板。执行同一脚本并加 `-Export`：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\build_windows.ps1 `
  -GodotPath "D:\Tools\Godot\Godot_v4.4.1-stable_win64_console.exe" -Export
```

产物位于 `dist/windows/`，分发时保留 EXE、PCK、DLL 和许可证。项目预设不嵌入资源，不修改 EXE 资源，不要求额外 rcedit 或签名证书。自己通过 MSVC 构建时，如果提示缺少 `VCRUNTIME140.dll`，安装微软官方 [Visual C++ x64 Redistributable](https://learn.microsoft.com/cpp/windows/latest-supported-vc-redist)。

## 验收建议

1. 初始地月距离约 363296 km；聚焦地球检查云层、晨昏线与月面按钮。
2. 查看完整系统，将倍率设为 ×86400，观察月球运动和轨迹积累。
3. 暂停，将地球质量改为 2 倍，再继续。轨道不再保持原轨道，预测线应同步变化。
4. 比较真实比例和视觉 ×4 模式：信息面板物理半径不能变化。
5. 重置，再选择精细 10 秒步长和最高倍率，关注“实际倍率”和预算提示。
6. 记录标准档／高档在 1080p 下的帧率、CPU 物理耗时、显存占用；本包没有虚构目标机器的性能结果。

如果找不到扩展，请先确认 x64 引擎、DLL 与 GDExtension 路径匹配；若 Vulkan 初始化失败，更新 AMD 驱动并尝试 `--rendering-method gl_compatibility`。缺失资源时应完整解压，而不是只复制 EXE。
