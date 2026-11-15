# 第二阶段已有产物恢复与下载

2026-11-15 核对，本地工作区和暂存区干净。源码、测试和 Windows DLL 已在 11d7aa617026c12afc8838e2b48a8a1bb78c2cda 提交中。保留原构建产物，未重新编译或重跑物理测试。

## Windows 下载

下载同目录的 Download-Windows.ps1，右键使用 PowerShell 运行，或执行 powershell -NoProfile -ExecutionPolicy Bypass -File .\\Download-Windows.ps1。脚本下载 14 个分卷，合并并验证完整 ZIP，输出到脚本所在目录。完整解压后运行 Start-Stage2.bat，兼容模式为 Start-Compatible.bat。

整包通过工具传输超过 300 秒限制，因此使用分卷交付。分卷必须合并后才能解压。

原 ZIP 大小 56798045 字节。
SHA-256 87f4a3bfbe03afb67ee2550fc7730907317428ca4712d9279cec2a57ebb9784a。

## 保留的实际记录

- docs/validation/stage2-windows-core.txt 中两项 CTest 全部通过。100 / 500 / 1000 碎片的每步计算耗时分别为 0.049253 / 1.22409 / 4.80067 ms，不包含绘制。
- docs/validation/stage2-package-test.log 记录 Windows Godot 4.4.1、OpenGL、AMD RX 5700，以及 STAGE2_RENDER_OK。保留系统根证书读取警告。
- 这次只核对现有文件、ZIP CRC 和下载哈希，未将历史测试冒充重新执行的测试。
- 第二阶段功能边界见 docs/STAGE2.md。仍为 2A–2C 原型，PR 保持 Draft。
