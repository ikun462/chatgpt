# 第二阶段 Windows 增量验证

2026-11-15，本机 Windows x64 / LLVM-MinGW Clang 23.1.5 / Godot 4.4.1。原 C++ 轨道测试和新增碰撞测试均通过。100、500、1000 碎片完整两两引力与接触每步约 0.049、1.224、4.808 ms，100 步均值，不含渲染。原 Godot 扩展/UI 回归通过，新增动态碎片与场景切换集成通过。OpenGL 实际渲染与独立打包 EXE 均已运行，保存了 100 碎片碰撞后的真实截图。截图采样窗口短，未测稳定 FPS，不能据此承诺目标帧率。

隔离环境首次运行因用户缓存/日志目录不可写发生崩溃，使用工作目录中的 APPDATA、LOCALAPPDATA 后解决。运行仍报告无法读取系统根证书存储，本项目离线模拟流程正常。没有把进程退出码单独作为界面通过依据。

范围与尚未完成项见 [STAGE2.md](STAGE2.md)。下方为保留的第一阶段历史记录。

# 实际验证记录

日期：2026-11-14。环境为云端 Debian 13 x86_64，不是用户的 Windows 电脑。所有下列“通过”均对应实际执行；没有根据代码推断测试成功。

## 结果范围

| 检查 | 状态 |
| --- | --- |
| GCC 14.2.0 编译 C++ 核心和 Linux GDExtension | 已通过 |
| CTest 物理测试 | 已通过 |
| Godot 4.4.1 导入资源、脚本解析 | 已通过 |
| Godot 无界面扩展与界面集成测试 | 已通过，0 failures |
| Linux 独立发布程序无界面启动 | 已通过 |
| Linux 独立发布程序 Vulkan Forward+ 实际画面 | 已通过，1920×1080 实际截图 |
| Linux 独立发布程序 OpenGL 兼容模式月面画面 | 已通过 |
| LLVM-MinGW 20251104 / Clang 21.1.5 构建 Windows x64 DLL | 已通过，PE32+ x86-64 |
| Godot 导出 Windows x64 EXE / PCK / DLL | 已通过 |
| Windows 原生启动、PowerShell/MSVC 脚本执行 | **未验证：当前是 Linux 环境** |
| 用户 i3 / RX 5700 XT 的 1080p 帧率、显存和内存占用 | **未测量，不承诺 60 FPS** |
| 碎片、碰撞响应、潮汐、完整太阳系 | 尚未实现，不在本阶段验证范围 |

图形检查使用 Mesa llvmpipe 软件渲染，Forward+ 对应 Vulkan 1.4.305。截图里的低 FPS 属于云端 CPU 软件渲染，不能用于判断 RX 5700 XT 的性能。截图通过运行时视口直接保存，没有生成或合成界面图。

发布检查曾发现调试绑定与发布引擎的内存布局不匹配。已在 CMake 中固定 `GODOTCPP_TARGET=template_release`，重建 Linux 和 Windows 扩展；重测编辑器内集成、发布无界面启动和发布图形运行均通过。源码包保留这个修复。

## 核心物理结果

真实 CTest 输出节选：

```
20 orbits dt=300s:
  max relative energy = 3.58139333173e-08
  normalized momentum residual = 5.72036884972e-14
  relative angular momentum residual = 4.96164184739e-14
  radius range = [363296440.008, 405503699.524] m

Kepler analytic reference, 864000 s integration:
  dt=7200 s error = 99929.4408256 m
  dt=3600 s error = 24984.0899705 m
  dt=1800 s error = 6246.13064244 m
  convergence ratios = 3.99972306151, 3.99993074123

4 massive bodies: conservation passed
Input validation and swept-contact rollback passed
Mass edit trajectory difference after 6000s: 54367.9668722 m
ALL PHYSICS TESTS PASSED
```

两体轨道检查持续约 20 个由参数计算的孤立二体周期；能量取全程最大误差，不只比较终点。动量残差按 `7.346e22 kg × 1100 m/s` 归一化。收敛性直接与独立求解 Kepler 方程的解析椭圆比较；步长减半误差约变为四分之一，符合二阶方法。上述参数下通过，不意味着任意用户极端场景都具有同样误差。

质量测试从完全相同的初始状态开始：一组保持原质量，另一组仅将地球质量加倍，积分 6000 秒后月球位置相差约 54.4 km；同时检查质量编辑没有偷偷修改位置和速度。这个结果证明质量参与加速度计算，而不是预设轨道动画。

## 扩展与界面测试

`godot/scripts/test_extension.gd` 实际验证：

- C++ 类注册、双精度状态数组、固定步长推进和零倍率暂停。
- 合法质量编辑；负质量、未知天体 ID 被拒绝。
- 修改质量保留位置、速度，后续轨道与基准分离；重新建立能量误差基线。
- 过高请求倍率被限制；物理预算／步长监测接口可用。
- 浮动原点将观察中心精确映射为零。
- 轨道预测存在且不推进真实模拟时间。
- 真实场景的质量滑块信号、物理半径与视觉放大分离、月球和系统视角、鼠标滚轮缩放、画质开关、重置、暂停。

输出：`EXTENSION_AND_UI_TESTS PASSED failures=0`。这里验证了场景逻辑和部分输入路径，不声称已经手工覆盖每种桌面操作。

## 复现

纯 C++ 测试不需要 Godot：

```sh
cmake -S . -B build/core -DSOLAR_BUILD_EXTENSION=OFF -DCMAKE_BUILD_TYPE=Release
cmake --build build/core --config Release
ctest --test-dir build/core -C Release -V --output-on-failure
```

完整构建参见 `WINDOWS.md`，或 Linux 执行 `tools/build_linux.sh`。扩展生成后：

```sh
godot --headless --path godot --editor --import
godot --headless --path godot --script res://scripts/test_extension.gd
```

有显示环境时可触发实际画面检查：

```sh
godot --path godot --audio-driver Dummy -- --render-smoke
godot --path godot --audio-driver Dummy -- --render-smoke --smoke-moon
```

运行 12 个绘制帧后退出，截图保存在 Godot `user://render_smoke.png`；不会更改用户项目源文件。第一阶段没有场景保存功能。原始测试及渲染日志见 `docs/validation/`。
